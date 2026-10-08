const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onMessagePublished } = require("firebase-functions/v2/pubsub");
const { initializeApp } = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");
const { google } = require("googleapis");
const { createHash, randomUUID } = require("crypto");

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

const { callAI } = require("./ai_clients");

initializeApp();

const db = getFirestore("databaseforrizzaj");

// ============================================================================
// CONFIGURATION
// ============================================================================

const PACKAGE_NAME = "com.prothon.rizzguru";

// Pub/Sub topic used by Google Play Real-time Developer Notifications.
const GOOGLE_PLAY_RTDN_TOPIC = "rizz-guru-play-rtdn";

// ============================================================================
// GOOGLE PLAY PRODUCTS
// ============================================================================

// Legacy product.
// Keep this temporarily so old/testing purchases do not break.
const LEGACY_TOP_UP_PRODUCT_ID = "coins_150_100";

// Current one-time coin products.
const COIN_PRODUCT_CONFIG = Object.freeze({
  coins_200_49: 200,
  coins_450_100: 450,
  coins_2400_500: 2400,
  coins_5000_1000: 5000,

  // Legacy product.
  [LEGACY_TOP_UP_PRODUCT_ID]: 150,
});

const COIN_PRODUCT_IDS = new Set(
  Object.keys(COIN_PRODUCT_CONFIG),
);

// Weekly auto-renewing subscription.
const WEEKLY_PRODUCT_ID = "rizz_weekly";

// Coins granted for each successful weekly subscription
// purchase/renewal.
const COINS_PER_WEEK = 750;

// All products accepted by the backend.
const GOOGLE_PLAY_PRODUCT_IDS = new Set([
  ...COIN_PRODUCT_IDS,
  WEEKLY_PRODUCT_ID,
]);

const STARTING_COINS = 20;

const FUNCTIONS_REGION = "asia-south1";

const AI_RESERVATION_TTL_MS = 2 * 60 * 1000;
const MAX_REQUEST_ID_LENGTH = 128;

// ============================================================================
// FIRESTORE REFERENCES
// ============================================================================

function userRef(uid) {
  return db.collection("users").doc(uid);
}

function aiReservationRef(uid, reservationId) {
  return userRef(uid)
    .collection("aiReservations")
    .doc(reservationId);
}

// Stores the relationship between a Google Play subscription purchase token
// and the Firebase user who completed the verified purchase.
function subscriptionMappingRef(purchaseToken) {
  return db
    .collection("googlePlaySubscriptions")
    .doc(hashValue(purchaseToken));
}

// ============================================================================
// AUTHENTICATION
// ============================================================================

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

// ============================================================================
// GENERAL HELPERS
// ============================================================================

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

function hashValue(value) {
  return createHash("sha256")
    .update(String(value))
    .digest("hex");
}

// ============================================================================
// GOOGLE PLAY HELPERS
// ============================================================================

function purchaseRef(idempotencyKey) {
  const tokenId = hashValue(idempotencyKey);

  return db
    .collection("usedPurchaseTokens")
    .doc(tokenId);
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

// ============================================================================
// GOOGLE PLAY SUBSCRIPTION MAPPING
// ============================================================================

async function linkSubscriptionToUser({
  uid,
  purchaseToken,
  productId,
}) {
  const ref =
    subscriptionMappingRef(
      purchaseToken,
    );

  await db.runTransaction(
    async (tx) => {
      const snapshot =
        await tx.get(ref);

      if (snapshot.exists) {
        const data =
          snapshot.data() ?? {};

        const existingUid =
          String(data.uid ?? "");

        if (
          existingUid &&
          existingUid !== uid
        ) {
          throw new HttpsError(
            "permission-denied",
            "This Google Play subscription belongs to another account.",
          );
        }
      }

      tx.set(
        ref,
        {
          uid,
          productId,
          purchaseTokenHash:
            hashValue(
              purchaseToken,
            ),
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    },
  );
}

// ============================================================================
// GOOGLE PLAY PURCHASE CREDITING
// ============================================================================

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

    // ------------------------------------------------------------------------
    // IDEMPOTENCY
    // ------------------------------------------------------------------------

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

      // For subscription renewals, still update a newer expiry date
      // if Google Play gives us one.
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

    // ------------------------------------------------------------------------
    // CREDIT COINS
    // ------------------------------------------------------------------------

    if (profileSnapshot.exists) {
      tx.update(profile, {
        coins: FieldValue.increment(coins),
        updatedAt:
          FieldValue.serverTimestamp(),
      });
    } else {
      tx.set(profile, {
        coins: STARTING_COINS + coins,
        reservedCoins: 0,
        createdAt:
          FieldValue.serverTimestamp(),
        updatedAt:
          FieldValue.serverTimestamp(),
      });
    }

    // ------------------------------------------------------------------------
    // RECORD PURCHASE
    // ------------------------------------------------------------------------

    const orderRecord = {
      uid,
      productId,
      purchaseTokenHash:
        hashValue(purchaseToken),
      idempotencyKeyHash:
        hashValue(idempotencyKey),
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

    // ------------------------------------------------------------------------
    // SUBSCRIPTION STATUS
    // ------------------------------------------------------------------------

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
  {
    region: FUNCTIONS_REGION,
  },
  async (request) => {
    const uid = requireUser(request);
    const ref = userRef(uid);

    const coins = await db.runTransaction(
      async (tx) => {
        const snapshot = await tx.get(ref);

        if (!snapshot.exists) {
          tx.set(ref, {
            coins: STARTING_COINS,
            reservedCoins: 0,
            createdAt:
              FieldValue.serverTimestamp(),
            updatedAt:
              FieldValue.serverTimestamp(),
          });

          return STARTING_COINS;
        }

        const data =
          snapshot.data() ?? {};

        if (
          typeof data.reservedCoins !==
          "number"
        ) {
          tx.update(ref, {
            reservedCoins: 0,
            updatedAt:
              FieldValue.serverTimestamp(),
          });
        }

        return Number(
          data.coins ?? 0,
        );
      },
    );

    return { coins };
  },
);

exports.getCoins = onCall(
  {
    region: FUNCTIONS_REGION,
  },
  async (request) => {
    const uid = requireUser(request);

    return {
      coins: await getUserCoins(uid),
    };
  },
);

exports.spendCoin = onCall(
  {
    region: FUNCTIONS_REGION,
  },
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
  {
    region: FUNCTIONS_REGION,
  },
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
      (
        !expiresAtMillis ||
        expiresAtMillis > Date.now()
      );

    return {
      active,
      expiresAt: expiresAtMillis
        ? new Date(
            expiresAtMillis,
          ).toISOString()
        : null,
      coins: Number(
        data.coins ?? 0,
      ),
    };
  },
);

// ============================================================================
// GOOGLE PLAY PURCHASE VERIFICATION
// ============================================================================

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

    if (!GOOGLE_PLAY_PRODUCT_IDS.has(productId)) {
      throw new HttpsError(
        "invalid-argument",
        "Unknown Google Play product.",
      );
    }

    try {
      const publisher =
        getPublisher();

      // ----------------------------------------------------------------------
      // COIN PRODUCTS
      // ----------------------------------------------------------------------

      if (COIN_PRODUCT_IDS.has(productId)) {
        const response =
          await publisher.purchases.products.get({
            packageName:
              PACKAGE_NAME,
            productId,
            token:
              purchaseToken,
          });

        const purchase =
          response.data;

        if (
          Number(
            purchase.purchaseState,
          ) !== 0
        ) {
          throw new HttpsError(
            "failed-precondition",
            "The Google Play purchase is not completed.",
          );
        }

        if (
          Number(
            purchase.consumptionState,
          ) === 1
        ) {
          throw new HttpsError(
            "failed-precondition",
            "This Google Play top-up has already been consumed.",
          );
        }

        const orderId =
          purchase.orderId ||
          purchaseToken;

        const coins =
          COIN_PRODUCT_CONFIG[productId];

        const result =
          await applyPurchase({
            uid,
            productId,
            purchaseToken,
            idempotencyKey:
              "topup:" +
              purchaseToken,
            coins,
          });

        // Consume only after the purchase has been
        // successfully credited/idempotently processed.
        await publisher.purchases.products.consume({
          packageName:
            PACKAGE_NAME,
          productId,
          token:
            purchaseToken,
        });

        return {
          coins:
            await getUserCoins(uid),
          credited:
            result.credited,
          productId,
          coinsAdded:
            coins,
          orderId,
        };
      }

      // ----------------------------------------------------------------------
      // WEEKLY SUBSCRIPTION
      // ----------------------------------------------------------------------

      const response =
        await publisher.purchases.subscriptionsv2.get({
          packageName:
            PACKAGE_NAME,
          token:
            purchaseToken,
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
        (
          subscription.lineItems ??
          []
        ).find(
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
        new Date(
          lineItem.expiryTime,
        );

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

      // Link the verified Play token to this Firebase account
      // before processing it for renewal notifications.
      await linkSubscriptionToUser({
        uid,
        purchaseToken,
        productId:
          WEEKLY_PRODUCT_ID,
      });

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
          coins:
            COINS_PER_WEEK,
          subscriptionExpiresAt,
        });

      // ----------------------------------------------------------------------
      // ACKNOWLEDGE SUBSCRIPTION
      // ----------------------------------------------------------------------

      if (
        subscription.acknowledgementState ===
        "ACKNOWLEDGEMENT_STATE_PENDING"
      ) {
        await publisher.purchases.subscriptions.acknowledge({
          packageName:
            PACKAGE_NAME,
          subscriptionId:
            WEEKLY_PRODUCT_ID,
          token:
            purchaseToken,
          requestBody: {},
        });
      }

      return {
        coins:
          await getUserCoins(uid),
        credited:
          result.credited,
        subscriptionActive:
          true,
        expiresAt:
          subscriptionExpiresAt.toISOString(),
        productId,
        coinsAdded:
          COINS_PER_WEEK,
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
// GOOGLE PLAY REAL-TIME DEVELOPER NOTIFICATIONS
// ============================================================================

exports.googlePlaySubscriptionNotifications =
  onMessagePublished(
    {
      topic:
        GOOGLE_PLAY_RTDN_TOPIC,
      region:
        FUNCTIONS_REGION,
    },
    async (event) => {
      const message =
        event.data.message;

      let notification = null;

      // Firebase's Pub/Sub wrapper exposes JSON messages through
      // event.data.message.json. Google Play RTDN publishes the
      // notification as a base64-encoded data field.
      try {
        if (
          message.json &&
          typeof message.json ===
            "object"
        ) {
          notification =
            message.json;
        } else if (
          message.data
        ) {
          const raw =
            Buffer.from(
              message.data,
              "base64",
            ).toString("utf8");

          notification =
            JSON.parse(raw);
        }
      } catch (error) {
        console.error(
          "Could not decode Google Play RTDN:",
          error,
        );

        // Do not retry malformed notifications forever.
        return;
      }

      if (!notification) {
        console.warn(
          "Google Play RTDN contained no data.",
        );
        return;
      }

      // ----------------------------------------------------------------------
      // PACKAGE CHECK
      // ----------------------------------------------------------------------

      if (
        notification.packageName !==
        PACKAGE_NAME
      ) {
        console.warn(
          "Ignoring RTDN for another package:",
          notification.packageName,
        );
        return;
      }

      // ----------------------------------------------------------------------
      // SUBSCRIPTION NOTIFICATION CHECK
      // ----------------------------------------------------------------------

      const subscriptionNotification =
        notification.subscriptionNotification;

      if (!subscriptionNotification) {
        // We only handle subscription notifications in this function.
        return;
      }

      const notificationType =
        Number(
          subscriptionNotification.notificationType,
        );

      const purchaseToken =
        String(
          subscriptionNotification.purchaseToken ??
            "",
        ).trim();

      if (!purchaseToken) {
        console.warn(
          "Google Play RTDN has no purchase token.",
        );
        return;
      }

      // ----------------------------------------------------------------------
      // FIND FIREBASE USER
      // ----------------------------------------------------------------------

      const mappingSnapshot =
        await subscriptionMappingRef(
          purchaseToken,
        ).get();

      if (!mappingSnapshot.exists) {
  console.warn(
    "No Firebase user mapping found for Google Play subscription token. Retrying RTDN.",
  );

  // The initial PURCHASED RTDN can arrive before the app finishes
  // backend verification. Throw so Pub/Sub retries the notification
  // instead of acknowledging and permanently losing the event.
  throw new Error(
    "Subscription mapping is not available yet.",
  );
}

      const mapping =
        mappingSnapshot.data() ?? {};

      const uid =
        String(
          mapping.uid ?? "",
        ).trim();

      if (!uid) {
        console.warn(
          "Google Play subscription mapping has no UID.",
        );
        return;
      }

      // ----------------------------------------------------------------------
      // GET AUTHORITATIVE GOOGLE PLAY STATE
      // ----------------------------------------------------------------------

      const publisher =
        getPublisher();

      let response;

      try {
        response =
          await publisher.purchases.subscriptionsv2.get(
            {
              packageName:
                PACKAGE_NAME,
              token:
                purchaseToken,
            },
          );
      } catch (error) {
        console.error(
          "Could not fetch Google Play subscription:",
          error,
        );

        // Throw so Pub/Sub can retry a transient Google API failure.
        throw error;
      }

      const subscription =
        response.data;

      const state =
        subscription.subscriptionState;

      // ----------------------------------------------------------------------
      // MAKE SURE THIS IS OUR WEEKLY PRODUCT
      // ----------------------------------------------------------------------

      const lineItem =
        (
          subscription.lineItems ??
          []
        ).find(
          (item) =>
            item.productId ===
            WEEKLY_PRODUCT_ID,
        );

      if (!lineItem) {
        console.warn(
          "RTDN subscription does not contain rizz_weekly.",
        );
        return;
      }

      const expiryTime =
        lineItem.expiryTime
          ? new Date(
              lineItem.expiryTime,
            )
          : null;

      const validExpiry =
        expiryTime &&
        !Number.isNaN(
          expiryTime.getTime(),
        )
          ? expiryTime
          : null;

      // ----------------------------------------------------------------------
      // PURCHASE / RENEWAL
      // ----------------------------------------------------------------------
      //
      // Google Play notification types:
      //
      // 2 = SUBSCRIPTION_RENEWED
      // 4 = SUBSCRIPTION_PURCHASED
      //
      // We only credit coins for these events.
      //
      // applyPurchase() makes this idempotent, so if the client already
      // credited the purchase and RTDN arrives afterwards, the same order
      // cannot credit the user twice.
      // ----------------------------------------------------------------------

      if (
        (
          notificationType === 2 ||
          notificationType === 4
        ) &&
        state ===
          "SUBSCRIPTION_STATE_ACTIVE"
      ) {
        const orderId =
          lineItem.latestSuccessfulOrderId ||
          subscription.latestOrderId;

        if (!orderId) {
          console.warn(
            "No successful order ID found for Google Play RTDN.",
          );
          return;
        }

        const result =
          await applyPurchase({
            uid,
            productId:
              WEEKLY_PRODUCT_ID,
            purchaseToken,
            idempotencyKey:
              "subscription:" +
              purchaseToken +
              ":" +
              orderId,
            coins:
              COINS_PER_WEEK,
            subscriptionExpiresAt:
              validExpiry,
          });

        // A new subscription purchase must be acknowledged. Renewals
// do not need acknowledgement.
if (
  notificationType === 4 &&
  subscription.acknowledgementState ===
    "ACKNOWLEDGEMENT_STATE_PENDING"
) {
  await publisher.purchases.subscriptions.acknowledge({
    packageName:
      PACKAGE_NAME,
    subscriptionId:
      WEEKLY_PRODUCT_ID,
    token:
      purchaseToken,
    requestBody: {},
  });
}

        // Refresh the mapping timestamp.
        await subscriptionMappingRef(
          purchaseToken,
        ).set(
          {
            uid,
            productId:
              WEEKLY_PRODUCT_ID,
            purchaseTokenHash:
              hashValue(
                purchaseToken,
              ),
            updatedAt:
              FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        console.log(
          "Google Play subscription processed.",
          {
            uid,
            notificationType,
            orderId,
            credited:
              result.credited,
            coinsAdded:
              result.credited
                ? COINS_PER_WEEK
                : 0,
          },
        );

        return;
      }

      // ----------------------------------------------------------------------
      // ACTIVE / GRACE PERIOD
      // ----------------------------------------------------------------------
      //
      // Cancellation does NOT necessarily mean immediate loss of access.
      // If Google still reports ACTIVE, the user keeps the subscription
      // until the expiry time.
      // ----------------------------------------------------------------------

      if (
        state ===
          "SUBSCRIPTION_STATE_ACTIVE" ||
        state ===
          "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
      ) {
        await userRef(uid).set(
          {
            subscriptionActive:
              true,
            subscriptionExpiresAt:
              validExpiry
                ? Timestamp.fromDate(
                    validExpiry,
                  )
                : null,
            subscriptionProductId:
              WEEKLY_PRODUCT_ID,
            updatedAt:
              FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        console.log(
          "Google Play subscription remains active.",
          {
            uid,
            notificationType,
            state,
          },
        );

        return;
      }

      // ----------------------------------------------------------------------
      // EXPIRED / ON HOLD / PAUSED / REVOKED / OTHER INACTIVE STATES
      // ----------------------------------------------------------------------

      await userRef(uid).set(
        {
          subscriptionActive:
            false,
          subscriptionExpiresAt:
            validExpiry
              ? Timestamp.fromDate(
                  validExpiry,
                )
              : null,
          subscriptionProductId:
            WEEKLY_PRODUCT_ID,
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      console.log(
        "Google Play subscription state updated.",
        {
          uid,
          notificationType,
          state,
        },
      );
    },
  );

// ============================================================================
// AI RESERVATION HELPERS
// ============================================================================

async function cleanupExpiredAIReservations(uid) {
  const profile = userRef(uid);
  const now = Timestamp.now();

  await db.runTransaction(async (tx) => {
    const profileSnapshot =
      await tx.get(profile);

    if (!profileSnapshot.exists) {
      return;
    }

    const reservationCollection =
      profile.collection("aiReservations");

    // IMPORTANT:
    // This query MUST be read through the transaction.
    // Do not use reservationCollection.get() here.
    const expiredQuery =
      reservationCollection
        .where(
          "status",
          "==",
          "reserved",
        )
        .where(
          "expiresAt",
          "<=",
          now,
        );

    const expiredSnapshot =
      await tx.get(expiredQuery);

    if (expiredSnapshot.empty) {
      return;
    }

    let totalToRelease = 0;

    for (
      const reservationDoc
      of expiredSnapshot.docs
    ) {
      const data =
        reservationDoc.data() ?? {};

      const cost =
        Number(data.cost ?? 0);

      if (cost > 0) {
        totalToRelease += cost;
      }

      tx.update(
        reservationDoc.ref,
        {
          status: "expired",
          expiredAt:
            FieldValue.serverTimestamp(),
        },
      );
    }

    if (totalToRelease <= 0) {
      return;
    }

    const profileData =
      profileSnapshot.data() ?? {};

    const currentReserved =
      Math.max(
        Number(
          profileData.reservedCoins ?? 0,
        ),
        0,
      );

    tx.update(profile, {
      reservedCoins:
        Math.max(
          currentReserved -
            totalToRelease,
          0,
        ),
      updatedAt:
        FieldValue.serverTimestamp(),
    });
  });
}

async function reserveAICoins(
  uid,
  coinCost,
  requestId = null,
) {
  await cleanupExpiredAIReservations(uid);

  const profile =
    userRef(uid);

  const reservationId =
    requestId
      ? hashValue(
          `${uid}:${requestId}`,
        ).slice(0, 40)
      : randomUUID();

  const reservation =
    aiReservationRef(
      uid,
      reservationId,
    );

  const expiresAt =
    new Date(
      Date.now() +
        AI_RESERVATION_TTL_MS,
    );

  return db.runTransaction(
    async (tx) => {
      const existing =
        await tx.get(
          reservation,
        );

      // --------------------------------------------------------
      // EXISTING REQUEST
      // --------------------------------------------------------

      if (existing.exists) {
        const existingData =
          existing.data() ?? {};

        if (
          existingData.status ===
            "completed" &&
          typeof existingData.reply ===
            "string" &&
          existingData.reply.trim()
            .length > 0
        ) {
          return {
            reservationId,
            alreadyCompleted:
              true,
            reply:
              existingData.reply,
            remainingCoins:
              Number(
                existingData.remainingCoins ??
                  0,
              ),
            costDeducted:
              Number(
                existingData.cost ??
                  coinCost,
              ),
          };
        }

        if (
          existingData.status ===
          "reserved"
        ) {
          throw new HttpsError(
            "aborted",
            "This AI request is already being processed.",
          );
        }

        if (
          existingData.status ===
          "released"
        ) {
          throw new HttpsError(
            "aborted",
            "This AI request has already failed. Please try again.",
          );
        }

        if (
          existingData.status ===
          "expired"
        ) {
          throw new HttpsError(
            "aborted",
            "This AI request expired. Please try again.",
          );
        }
      }

      const profileSnapshot =
        await tx.get(
          profile,
        );

      if (!profileSnapshot.exists) {
        throw new HttpsError(
          "failed-precondition",
          "User profile does not exist.",
        );
      }

      const data =
        profileSnapshot.data() ?? {};

      const coins =
        Number(
          data.coins ?? 0,
        );

      const reservedCoins =
        Math.max(
          Number(
            data.reservedCoins ??
              0,
          ),
          0,
        );

      const availableCoins =
        coins -
        reservedCoins;

      if (
        availableCoins <
        coinCost
      ) {
        throw new HttpsError(
          "resource-exhausted",
          `Insufficient coins. Need ${coinCost}, have ${Math.max(
            availableCoins,
            0,
          )}.`,
        );
      }

      tx.update(
        profile,
        {
          reservedCoins:
            reservedCoins +
            coinCost,
          updatedAt:
            FieldValue.serverTimestamp(),
        },
      );

      tx.create(
        reservation,
        {
          uid,
          requestId:
            requestId || null,
          cost:
            coinCost,
          status:
            "reserved",
          createdAt:
            FieldValue.serverTimestamp(),
          expiresAt:
            Timestamp.fromDate(
              expiresAt,
            ),
        },
      );

      return {
        reservationId,
        alreadyCompleted:
          false,
        remainingAvailableCoins:
          availableCoins -
          coinCost,
      };
    },
  );
}

async function releaseAICoins(
  uid,
  reservationId,
) {
  const profile =
    userRef(uid);

  const reservation =
    aiReservationRef(
      uid,
      reservationId,
    );

  await db.runTransaction(
    async (tx) => {
      const reservationSnapshot =
        await tx.get(
          reservation,
        );

      if (
        !reservationSnapshot.exists
      ) {
        return;
      }

      const reservationData =
        reservationSnapshot.data() ??
        {};

      if (
        reservationData.status !==
        "reserved"
      ) {
        return;
      }

      const profileSnapshot =
        await tx.get(
          profile,
        );

      if (
        !profileSnapshot.exists
      ) {
        throw new HttpsError(
          "failed-precondition",
          "User profile does not exist.",
        );
      }

      const profileData =
        profileSnapshot.data() ??
        {};

      const reservedCoins =
        Math.max(
          Number(
            profileData.reservedCoins ??
              0,
          ),
          0,
        );

      const cost =
        Number(
          reservationData.cost ??
            0,
        );

      tx.update(
        profile,
        {
          reservedCoins:
            Math.max(
              reservedCoins -
                cost,
              0,
            ),
          updatedAt:
            FieldValue.serverTimestamp(),
        },
      );

      tx.update(
        reservation,
        {
          status:
            "released",
          releasedAt:
            FieldValue.serverTimestamp(),
        },
      );
    },
  );
}

async function finalizeAICoins(
  uid,
  reservationId,
  cleanedReply,
) {
  const profile =
    userRef(uid);

  const reservation =
    aiReservationRef(
      uid,
      reservationId,
    );

  return db.runTransaction(
    async (tx) => {
      const reservationSnapshot =
        await tx.get(
          reservation,
        );

      if (
        !reservationSnapshot.exists
      ) {
        throw new HttpsError(
          "not-found",
          "AI reservation was not found.",
        );
      }

      const reservationData =
        reservationSnapshot.data() ??
        {};

      // --------------------------------------------------------
      // ALREADY COMPLETED
      // --------------------------------------------------------

      if (
        reservationData.status ===
        "completed"
      ) {
        const profileSnapshot =
          await tx.get(
            profile,
          );

        const profileData =
          profileSnapshot.data() ??
          {};

        return {
          remainingCoins:
            Number(
              profileData.coins ??
                0,
            ),
          costDeducted:
            Number(
              reservationData.cost ??
                0,
            ),
          alreadyCompleted:
            true,
          reply:
            reservationData.reply ||
            cleanedReply,
        };
      }

      // --------------------------------------------------------
      // RESERVATION MUST BE ACTIVE
      // --------------------------------------------------------

      if (
        reservationData.status !==
        "reserved"
      ) {
        throw new HttpsError(
          "failed-precondition",
          "AI reservation is no longer active.",
        );
      }

      // --------------------------------------------------------
      // CHECK EXPIRATION
      // --------------------------------------------------------

      const expiresAtMillis =
        timestampMillis(
          reservationData.expiresAt,
        );

      if (
        expiresAtMillis > 0 &&
        expiresAtMillis <=
          Date.now()
      ) {
        throw new HttpsError(
          "deadline-exceeded",
          "AI reservation expired.",
        );
      }

      const profileSnapshot =
        await tx.get(
          profile,
        );

      if (
        !profileSnapshot.exists
      ) {
        throw new HttpsError(
          "failed-precondition",
          "User profile does not exist.",
        );
      }

      const profileData =
        profileSnapshot.data() ??
        {};

      const currentCoins =
        Number(
          profileData.coins ??
            0,
        );

      const reservedCoins =
        Math.max(
          Number(
            profileData.reservedCoins ??
              0,
          ),
          0,
        );

      const cost =
        Number(
          reservationData.cost ??
            0,
        );

      if (
        cost <= 0 ||
        reservedCoins < cost ||
        currentCoins < cost
      ) {
        throw new HttpsError(
          "failed-precondition",
          "AI reservation cannot be finalized.",
        );
      }

      const newCoins =
        currentCoins -
        cost;

      const newReservedCoins =
        reservedCoins -
        cost;

      tx.update(
        profile,
        {
          coins:
            newCoins,
          reservedCoins:
            Math.max(
              newReservedCoins,
              0,
            ),
          updatedAt:
            FieldValue.serverTimestamp(),
        },
      );

      tx.update(
        reservation,
        {
          status:
            "completed",
          reply:
            cleanedReply,
          remainingCoins:
            newCoins,
          completedAt:
            FieldValue.serverTimestamp(),
        },
      );

      return {
        remainingCoins:
          newCoins,
        costDeducted:
          cost,
        alreadyCompleted:
          false,
        reply:
          cleanedReply,
      };
    },
  );
}

// ============================================================================
// 3-TIER AI REPLY GENERATION
// ============================================================================

exports.generateReply = onCall(
  {
    region: FUNCTIONS_REGION,

    // AICredits API key stays server-side.
    secrets: [
      "AICREDITS_API_KEY",
    ],
  },

  async (request) => {
    const uid =
      requireUser(request);

    // ----------------------------------------------------------
    // REQUEST DATA
    // ----------------------------------------------------------

    const tier =
      String(
        request.data?.tier ??
          "basic",
      )
        .trim()
        .toLowerCase();

    const message =
      String(
        request.data?.message ??
          "",
      ).trim();

    const mood =
      String(
        request.data?.mood ??
          "natural",
      ).trim();

    const rawRequestId =
      String(
        request.data?.requestId ??
          "",
      ).trim();

    const requestId =
      rawRequestId
        ? rawRequestId.slice(
            0,
            MAX_REQUEST_ID_LENGTH,
          )
        : null;

    const conversation =
      Array.isArray(
        request.data?.conversation,
      )
        ? request.data.conversation
        : [];

    // ----------------------------------------------------------
    // VALIDATE TIER
    // ----------------------------------------------------------

    if (!isValidTier(tier)) {
      throw new HttpsError(
        "invalid-argument",
        `Invalid AI tier: ${tier}. Must be 'basic', 'smart', or 'premium'.`,
      );
    }

    const tierConfig =
      getTierConfig(tier);

    const coinCost =
      getTierCost(tier);

    if (
      !Number.isInteger(
        coinCost,
      ) ||
      coinCost <= 0
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Invalid coin cost for this AI tier.",
      );
    }

    if (
      !isTierConfigured(
        tierConfig,
      )
    ) {
      throw new HttpsError(
        "failed-precondition",
        `${tier} tier is not configured on the server.`,
      );
    }

    // ----------------------------------------------------------
    // VALIDATE MESSAGE
    // ----------------------------------------------------------

    if (!message) {
      throw new HttpsError(
        "invalid-argument",
        "Message cannot be empty.",
      );
    }

    if (
      message.length > 5000
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Message is too long (max 5000 chars).",
      );
    }

    // ----------------------------------------------------------
    // RESERVE COINS
    // ----------------------------------------------------------

    let reservation;

    try {
      reservation =
        await reserveAICoins(
          uid,
          coinCost,
          requestId,
        );
    } catch (error) {
      if (
        error instanceof HttpsError
      ) {
        throw error;
      }

      console.error(
        "AI coin reservation failed:",
        error,
      );

      throw new HttpsError(
        "internal",
        "Could not reserve coins.",
      );
    }

    // ----------------------------------------------------------
    // DUPLICATE COMPLETED REQUEST
    // ----------------------------------------------------------

    if (
      reservation.alreadyCompleted
    ) {
      return {
        reply:
          reservation.reply,
        remainingCoins:
          reservation.remainingCoins,
        tier,
        costDeducted:
          reservation.costDeducted,
        alreadyCompleted:
          true,
      };
    }

    const reservationId =
      reservation.reservationId;

    // ----------------------------------------------------------
    // BUILD PROMPT
    // ----------------------------------------------------------

    try {
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
          content:
            systemPrompt,
        },
      ];

      const recentConversation =
        conversation.length > 8
          ? conversation.slice(-8)
          : conversation;

      for (
        const item
        of recentConversation
      ) {
        if (!item) {
          continue;
        }

        const itemRole =
          item.role;

        const itemContent =
          String(
            item.content ??
              "",
          ).trim();

        if (!itemContent) {
          continue;
        }

        if (
          itemRole !== "user" &&
          itemRole !== "assistant"
        ) {
          continue;
        }

        const safeContent =
          itemContent.length > 5000
            ? itemContent.slice(
                0,
                5000,
              )
            : itemContent;

        messages.push({
          role:
            itemRole,
          content:
            safeContent,
        });
      }

      messages.push({
        role: "user",
        content:
          message,
      });

      // --------------------------------------------------------
      // CALL AI
      // --------------------------------------------------------

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

        await releaseAICoins(
          uid,
          reservationId,
        ).catch(
          (releaseError) => {
            console.error(
              "Failed to release AI reservation:",
              releaseError,
            );
          },
        );

        throw error;
      }

      // --------------------------------------------------------
      // CLEAN REPLY
      // --------------------------------------------------------

      let cleanedReply;

      try {
        cleanedReply =
          cleanReply(
            aiReply,
          );
      } catch (error) {
        console.error(
          "AI reply cleaning failed:",
          error,
        );

        await releaseAICoins(
          uid,
          reservationId,
        ).catch(
          (releaseError) => {
            console.error(
              "Failed to release AI reservation:",
              releaseError,
            );
          },
        );

        throw new HttpsError(
          "internal",
          "AI returned an invalid reply.",
        );
      }

      if (
        !cleanedReply ||
        typeof cleanedReply !==
          "string" ||
        cleanedReply.trim()
          .length === 0
      ) {
        await releaseAICoins(
          uid,
          reservationId,
        ).catch(
          (releaseError) => {
            console.error(
              "Failed to release AI reservation:",
              releaseError,
            );
          },
        );

        throw new HttpsError(
          "internal",
          "AI returned an empty reply.",
        );
      }

      // --------------------------------------------------------
      // FINALIZE PAYMENT
      // --------------------------------------------------------

      let paymentResult;

      try {
        paymentResult =
          await finalizeAICoins(
            uid,
            reservationId,
            cleanedReply,
          );
      } catch (error) {
        console.error(
          "AI coin finalization failed:",
          error,
        );

        await releaseAICoins(
          uid,
          reservationId,
        ).catch(
          (releaseError) => {
            console.error(
              "Failed to release AI reservation after finalization error:",
              releaseError,
            );
          },
        );

        if (
          error instanceof HttpsError
        ) {
          throw error;
        }

        throw new HttpsError(
          "internal",
          "Could not finalize the AI reply payment.",
        );
      }

      // --------------------------------------------------------
      // SUCCESS
      // --------------------------------------------------------

      return {
        reply:
          paymentResult.reply ||
          cleanedReply,

        remainingCoins:
          paymentResult.remainingCoins,

        tier,

        costDeducted:
          paymentResult.costDeducted,

        alreadyCompleted:
          paymentResult.alreadyCompleted ===
          true,
      };
    } catch (error) {
      // --------------------------------------------------------
      // SAFETY RELEASE
      // --------------------------------------------------------

      await releaseAICoins(
        uid,
        reservationId,
      ).catch(
        (releaseError) => {
          console.error(
            "Failed to release AI reservation:",
            releaseError,
          );
        },
      );

      if (
        error instanceof HttpsError
      ) {
        throw error;
      }

      console.error(
        "Unexpected generateReply error:",
        error,
      );

      throw new HttpsError(
        "internal",
        "Failed to generate reply.",
      );
    }
  },
);
