const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");
const { google } = require("googleapis");
const { createHash } = require("crypto");

const {
  getTierConfig,
  isTierConfigured,
  getTierCost,
  isValidTier,
} = require("./ai_reply_tiers");

const {
  isHinglish,
  getSystemPrompt,
  cleanReply,
} = require("./reply_prompt");

const { callAI } = require("./ai_client");

initializeApp();

const db = getFirestore("databaseforrizzaj");

const PACKAGE_NAME = "com.prothon.rizzguru";
const TOP_UP_PRODUCT_ID = "coins_150_100";
const WEEKLY_PRODUCT_ID = "rizz_weekly";

const STARTING_COINS = 20;
const COINS_PER_TOPUP = 150;
const COINS_PER_WEEK = 150;

const FUNCTIONS_REGION = "asia-south1";

function userRef(uid) {
  return db.collection("users").doc(uid);
}

function requireUser(request) {
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "Login required.",
    );
  }

  return uid;
}

function purchaseRef(idempotencyKey) {
  const tokenId = createHash("sha256")
    .update(idempotencyKey)
    .digest("hex");

  return db.collection("usedPurchaseTokens").doc(tokenId);
}

function getPublisher() {
  const rawCredentials =
    process.env.GOOGLE_SERVICE_ACCOUNT_JSON;

  if (!rawCredentials) {
    throw new HttpsError(
      "failed-precondition",
      "Google Play verification is not configured.",
    );
  }

  let credentials;

  try {
    credentials = JSON.parse(rawCredentials);
  } catch (_) {
    throw new HttpsError(
      "failed-precondition",
      "Google Play service account configuration is invalid.",
    );
  }

  const auth = new google.auth.GoogleAuth({
    credentials,
    scopes: [
      "https://www.googleapis.com/auth/androidpublisher",
    ],
  });

  return google.androidpublisher({
    version: "v3",
    auth,
  });
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") {
    return value.toMillis();
  }

  return 0;
}

async function getUserCoins(uid) {
  const snapshot = await userRef(uid).get();

  return Number(
    snapshot.data()?.coins ?? 0,
  );
}

async function applyPurchase({
  uid,
  productId,
  purchaseToken,
  idempotencyKey,
  coins,
  subscriptionExpiresAt,
}) {
  const profile = userRef(uid);
  const used = purchaseRef(idempotencyKey);

  return db.runTransaction(async (tx) => {
    const usedSnapshot = await tx.get(used);
    const profileSnapshot = await tx.get(profile);

    const profileData =
      profileSnapshot.data() ?? {};

    const currentCoins =
      Number(profileData.coins ?? 0);

    if (usedSnapshot.exists) {
      const usedData =
        usedSnapshot.data() ?? {};

      if (
        usedData.uid !== uid ||
        usedData.productId !== productId
      ) {
        throw new HttpsError(
          "permission-denied",
          "This Google Play purchase belongs to another account.",
        );
      }

      if (subscriptionExpiresAt) {
        const currentExpiry =
          timestampMillis(
            profileData.subscriptionExpiresAt,
          );

        if (
          subscriptionExpiresAt.getTime() >
          currentExpiry
        ) {
          tx.set(
            profile,
            {
              subscriptionActive: true,
              subscriptionExpiresAt:
                Timestamp.fromDate(
                  subscriptionExpiresAt,
                ),
              subscriptionProductId:
                productId,
              updatedAt:
                FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }
      }

      return {
        coins: currentCoins,
        credited: false,
      };
    }

    if (profileSnapshot.exists) {
      tx.update(profile, {
        coins: FieldValue.increment(coins),
        updatedAt:
          FieldValue.serverTimestamp(),
      });
    } else {
      tx.set(profile, {
        coins: STARTING_COINS + coins,
        createdAt:
          FieldValue.serverTimestamp(),
        updatedAt:
          FieldValue.serverTimestamp(),
      });
    }

    const orderRecord = {
      uid,
      productId,
      purchaseTokenHash: createHash("sha256")
        .update(purchaseToken)
        .digest("hex"),
      idempotencyKeyHash: createHash("sha256")
        .update(idempotencyKey)
        .digest("hex"),
      createdAt:
        FieldValue.serverTimestamp(),
    };

    if (subscriptionExpiresAt) {
      orderRecord.subscriptionExpiresAt =
        Timestamp.fromDate(
          subscriptionExpiresAt,
        );
    }

    tx.create(used, orderRecord);

    if (subscriptionExpiresAt) {
      tx.set(
        profile,
        {
          subscriptionActive: true,
          subscriptionExpiresAt:
            Timestamp.fromDate(
              subscriptionExpiresAt,
            ),
          subscriptionProductId:
            productId,
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    return {
      coins: profileSnapshot.exists
        ? currentCoins + coins
        : STARTING_COINS + coins,
      credited: true,
    };
  });
}

// ============================================================================
// EXISTING FUNCTIONS
// ============================================================================

exports.ensureUserProfile = onCall(
  { region: FUNCTIONS_REGION },
  async (request) => {
    const uid = requireUser(request);
    const ref = userRef(uid);

    const coins = await db.runTransaction(
      async (tx) => {
        const snapshot = await tx.get(ref);

        if (!snapshot.exists) {
          tx.set(ref, {
            coins: STARTING_COINS,
            createdAt:
              FieldValue.serverTimestamp(),
            updatedAt:
              FieldValue.serverTimestamp(),
          });

          return STARTING_COINS;
        }

        return Number(
          snapshot.data()?.coins ?? 0,
        );
      },
    );

    return { coins };
  },
);

exports.getCoins = onCall(
  { region: FUNCTIONS_REGION },
  async (request) => {
    const uid = requireUser(request);

    return {
      coins: await getUserCoins(uid),
    };
  },
);

exports.spendCoin = onCall(
  { region: FUNCTIONS_REGION },
  async (request) => {
    const uid = requireUser(request);
    const ref = userRef(uid);

    return db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);

      const coins = Number(
        snapshot.data()?.coins ?? 0,
      );

      if (!snapshot.exists || coins <= 0) {
        return {
          success: false,
          coins: Math.max(coins, 0),
        };
      }

      const nextCoins = coins - 1;

      tx.update(ref, {
        coins: nextCoins,
        updatedAt:
          FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        coins: nextCoins,
      };
    });
  },
);

exports.getSubscriptionStatus = onCall(
  { region: FUNCTIONS_REGION },
  async (request) => {
    const uid = requireUser(request);

    const data =
      (await userRef(uid).get()).data() ?? {};

    const expiresAtMillis =
      timestampMillis(
        data.subscriptionExpiresAt,
      );

    const active =
      data.subscriptionActive === true &&
      (!expiresAtMillis ||
        expiresAtMillis > Date.now());

    return {
      active,
      expiresAt: expiresAtMillis
        ? new Date(
            expiresAtMillis,
          ).toISOString()
        : null,
      coins: Number(data.coins ?? 0),
    };
  },
);

exports.verifyGooglePlayPurchase = onCall(
  {
    region: FUNCTIONS_REGION,
    secrets: [
      "GOOGLE_SERVICE_ACCOUNT_JSON",
    ],
  },
  async (request) => {
    const uid = requireUser(request);

    const productId = String(
      request.data?.productId ?? "",
    );

    const purchaseToken = String(
      request.data?.purchaseToken ?? "",
    );

    if (!productId || !purchaseToken) {
      throw new HttpsError(
        "invalid-argument",
        "productId and purchaseToken are required.",
      );
    }

    if (
      ![
        TOP_UP_PRODUCT_ID,
        WEEKLY_PRODUCT_ID,
      ].includes(productId)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Unknown Google Play product.",
      );
    }

    try {
      const publisher = getPublisher();

      if (productId === TOP_UP_PRODUCT_ID) {
        const response =
          await publisher.purchases.products.get({
            packageName: PACKAGE_NAME,
            productId: TOP_UP_PRODUCT_ID,
            token: purchaseToken,
          });

        const purchase = response.data;

        if (
          Number(purchase.purchaseState) !== 0
        ) {
          throw new HttpsError(
            "failed-precondition",
            "The Google Play purchase is not completed.",
          );
        }

        if (
          Number(purchase.consumptionState) === 1
        ) {
          throw new HttpsError(
            "failed-precondition",
            "This Google Play top-up has already been consumed.",
          );
        }

        const orderId =
          purchase.orderId ||
          purchaseToken;

        const result =
          await applyPurchase({
            uid,
            productId,
            purchaseToken,
            idempotencyKey:
              "topup:" + purchaseToken,
            coins: COINS_PER_TOPUP,
          });

        if (
          Number(purchase.consumptionState) !==
          1
        ) {
          await publisher.purchases.products.consume({
            packageName: PACKAGE_NAME,
            productId:
              TOP_UP_PRODUCT_ID,
            token: purchaseToken,
          });
        }

        return {
          coins: await getUserCoins(uid),
          credited: result.credited,
          productId,
          orderId,
        };
      }

      const response =
        await publisher.purchases.subscriptionsv2.get({
          packageName: PACKAGE_NAME,
          token: purchaseToken,
        });

      const subscription =
        response.data;

      const state =
        subscription.subscriptionState;

      if (
        state !==
          "SUBSCRIPTION_STATE_ACTIVE" &&
        state !==
          "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
      ) {
        throw new HttpsError(
          "failed-precondition",
          "The weekly subscription is not active.",
        );
      }

      const lineItem =
        (subscription.lineItems ?? []).find(
          (item) =>
            item.productId ===
            WEEKLY_PRODUCT_ID,
        );

      if (!lineItem?.expiryTime) {
        throw new HttpsError(
          "failed-precondition",
          "Subscription expiry is unavailable.",
        );
      }

      const subscriptionExpiresAt =
        new Date(lineItem.expiryTime);

      if (
        Number.isNaN(
          subscriptionExpiresAt.getTime(),
        )
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Subscription expiry is invalid.",
        );
      }

      const orderId =
        lineItem.latestSuccessfulOrderId;

      if (!orderId) {
        throw new HttpsError(
          "failed-precondition",
          "Google Play did not return a successful order ID.",
        );
      }

      const result =
        await applyPurchase({
          uid,
          productId,
          purchaseToken,
          idempotencyKey:
            "subscription:" +
            purchaseToken +
            ":" +
            orderId,
          coins: COINS_PER_WEEK,
          subscriptionExpiresAt,
        });

      if (
        subscription.acknowledgementState ===
        "ACKNOWLEDGEMENT_STATE_PENDING"
      ) {
        await publisher.purchases.subscriptions.acknowledge({
          packageName: PACKAGE_NAME,
          subscriptionId:
            WEEKLY_PRODUCT_ID,
          token: purchaseToken,
          requestBody: {},
        });
      }

      return {
        coins: await getUserCoins(uid),
        credited: result.credited,
        subscriptionActive: true,
        expiresAt:
          subscriptionExpiresAt.toISOString(),
        productId,
        orderId,
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error(
        "Google Play purchase verification failed",
        error,
      );

      throw new HttpsError(
        "internal",
        "Could not verify the purchase with Google Play.",
      );
    }
  },
);

// ============================================================================
// 3-TIER AI REPLY GENERATION
// ============================================================================

exports.generateReply = onCall(
  {
    region: FUNCTIONS_REGION,
    secrets: [
      "AICREDITS_API_KEY",
    ],
  },

  async (request) => {
    const uid = requireUser(request);

    const tier = String(
      request.data?.tier ?? "",
    )
      .trim()
      .toLowerCase();

    const message = String(
      request.data?.message ?? "",
    ).trim();

    const mood = String(
      request.data?.mood ?? "natural",
    ).trim();

    const conversation =
      Array.isArray(
        request.data?.conversation,
      )
        ? request.data.conversation
        : [];

    // ----------------------------------------------------------
    // Validate tier
    // ----------------------------------------------------------

    if (!isValidTier(tier)) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid AI tier.",
      );
    }

    const tierConfig =
      getTierConfig(tier);

    const coinCost =
      getTierCost(tier);

    if (
      !Number.isInteger(coinCost) ||
      coinCost <= 0
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Invalid coin cost for this AI tier.",
      );
    }

    if (
      !isTierConfigured(tierConfig)
    ) {
      throw new HttpsError(
        "failed-precondition",
        `${tier} tier is not configured on the server.`,
      );
    }

    // ----------------------------------------------------------
    // Validate message
    // ----------------------------------------------------------

    if (!message) {
      throw new HttpsError(
        "invalid-argument",
        "Message cannot be empty.",
      );
    }

    if (message.length > 5000) {
      throw new HttpsError(
        "invalid-argument",
        "Message is too long.",
      );
    }

    // ----------------------------------------------------------
    // Reserve coins
    //
    // We do NOT reduce the actual "coins" balance here.
    // We temporarily reserve the coins so two simultaneous
    // requests cannot both spend the same balance.
    // ----------------------------------------------------------

    const profile = userRef(uid);

    const reservationId =
      `${uid}_${Date.now()}_${Math.random()
        .toString(36)
        .slice(2)}`;

    const reservationRef = db
      .collection("aiReplyReservations")
      .doc(reservationId);

    await db.runTransaction(
      async (tx) => {
        const snapshot =
          await tx.get(profile);

        const data =
          snapshot.data() ?? {};

        const currentCoins =
          Number(data.coins ?? 0);

        const reservedCoins =
          Number(
            data.reservedCoins ?? 0,
          );

        const availableCoins =
          currentCoins -
          reservedCoins;

        if (
          availableCoins <
          coinCost
        ) {
          throw new HttpsError(
            "resource-exhausted",
            `Insufficient coins. You need ${coinCost} coins for ${tier}.`,
          );
        }

        tx.set(
          reservationRef,
          {
            uid,
            tier,
            cost: coinCost,
            status: "reserved",
            createdAt:
              FieldValue.serverTimestamp(),
          },
        );

        tx.set(
          profile,
          {
            reservedCoins:
              reservedCoins +
              coinCost,
            updatedAt:
              FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      },
    );

    // ----------------------------------------------------------
    // Build prompt
    // ----------------------------------------------------------

    const hinglish =
      isHinglish(message);

    const systemPrompt =
      getSystemPrompt(
        mood,
        hinglish,
      );

    const messages = [
      {
        role: "system",
        content: systemPrompt,
      },
    ];

    const recentConversation =
      conversation.length > 8
        ? conversation.slice(-8)
        : conversation;

    for (
      const item of recentConversation
    ) {
      if (!item) continue;

      const role = item.role;

      const content = String(
        item.content ?? "",
      ).trim();

      if (!content) continue;

      if (
        role !== "user" &&
        role !== "assistant"
      ) {
        continue;
      }

      messages.push({
        role,
        content,
      });
    }

    messages.push({
      role: "user",
      content: message,
    });

    // ----------------------------------------------------------
    // Call AI
    // ----------------------------------------------------------

    let aiReply;

    try {
      aiReply =
        await callAI(
          tierConfig,
          messages,
        );
    } catch (error) {
      console.error(
        `AI call failed for ${tier} tier:`,
        error,
      );

      // Release reservation.
      await db.runTransaction(
        async (tx) => {
          const profileSnapshot =
            await tx.get(profile);

          const reservationSnapshot =
            await tx.get(
              reservationRef,
            );

          if (
            !reservationSnapshot.exists
          ) {
            return;
          }

          const profileData =
            profileSnapshot.data() ??
            {};

          const reservedCoins =
            Number(
              profileData.reservedCoins ??
                0,
            );

          const reservationData =
            reservationSnapshot.data() ??
            {};

          const reservationCost =
            Number(
              reservationData.cost ??
                coinCost,
            );

          tx.set(
            profile,
            {
              reservedCoins:
                Math.max(
                  0,
                  reservedCoins -
                    reservationCost,
                ),
              updatedAt:
                FieldValue.serverTimestamp(),
            },
            { merge: true },
          );

          tx.update(
            reservationRef,
            {
              status: "released",
              releasedAt:
                FieldValue.serverTimestamp(),
            },
          );
        },
      );

      throw new HttpsError(
        "internal",
        "Failed to generate reply. Please try again.",
      );
    }

    // ----------------------------------------------------------
    // Clean AI reply
    // ----------------------------------------------------------

    const cleanedReply =
      cleanReply(aiReply);

    if (!cleanedReply) {
      // Release reservation.
      await db.runTransaction(
        async (tx) => {
          const profileSnapshot =
            await tx.get(profile);

          const reservationSnapshot =
            await tx.get(
              reservationRef,
            );

          if (
            !reservationSnapshot.exists
          ) {
            return;
          }

          const profileData =
            profileSnapshot.data() ??
            {};

          const reservedCoins =
            Number(
              profileData.reservedCoins ??
                0,
            );

          tx.set(
            profile,
            {
              reservedCoins:
                Math.max(
                  0,
                  reservedCoins -
                    coinCost,
                ),
              updatedAt:
                FieldValue.serverTimestamp(),
            },
            { merge: true },
          );

          tx.update(
            reservationRef,
            {
              status: "released",
              releasedAt:
                FieldValue.serverTimestamp(),
            },
          );
        },
      );

      throw new HttpsError(
        "internal",
        "AI returned an empty reply.",
      );
    }

    // ----------------------------------------------------------
    // Finalize payment
    //
    // Now that AI succeeded:
    // reservedCoins decreases
    // actual coins decrease
    // ----------------------------------------------------------

    const finalResult =
      await db.runTransaction(
        async (tx) => {
          const profileSnapshot =
            await tx.get(profile);

          const reservationSnapshot =
            await tx.get(
              reservationRef,
            );

          if (
            !reservationSnapshot.exists
          ) {
            throw new HttpsError(
              "failed-precondition",
              "AI reply reservation was not found.",
            );
          }

          const reservationData =
            reservationSnapshot.data() ??
            {};

          if (
            reservationData.status !==
            "reserved"
          ) {
            throw new HttpsError(
              "failed-precondition",
              "AI reply reservation is no longer active.",
            );
          }

          const data =
            profileSnapshot.data() ??
            {};

          const currentCoins =
            Number(
              data.coins ?? 0,
            );

          const reservedCoins =
            Number(
              data.reservedCoins ??
                0,
            );

          if (
            currentCoins <
            coinCost
          ) {
            throw new HttpsError(
              "resource-exhausted",
              "Coin balance is insufficient.",
            );
          }

          if (
            reservedCoins <
            coinCost
          ) {
            throw new HttpsError(
              "failed-precondition",
              "Coin reservation is invalid.",
            );
          }

          const newCoins =
            currentCoins -
            coinCost;

          const newReservedCoins =
            reservedCoins -
            coinCost;

          tx.update(
            profile,
            {
              coins: newCoins,
              reservedCoins:
                Math.max(
                  0,
                  newReservedCoins,
                ),
              updatedAt:
                FieldValue.serverTimestamp(),
            },
          );

          tx.update(
            reservationRef,
            {
              status: "completed",
              completedAt:
                FieldValue.serverTimestamp(),
            },
          );

          return {
            reply: cleanedReply,
            remainingCoins:
              newCoins,
            tier,
            costDeducted:
              coinCost,
          };
        },
      );

    return finalResult;
  },
);