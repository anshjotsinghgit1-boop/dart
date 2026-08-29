const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { google } = require("googleapis");
const { createHash } = require("crypto");

initializeApp();
const db = getFirestore();

const PACKAGE_NAME = "com.prothon.rizzguru";
const TOP_UP_PRODUCT_ID = "coins_150_100";
const WEEKLY_PRODUCT_ID = "rizz_weekly";
const COINS_PER_TOPUP = 150;
const COINS_PER_WEEK = 150;
const FUNCTIONS_REGION = "asia-south1";

function userRef(uid) {
  return db.collection("users").doc(uid);
}

function requireUser(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Login required.");
  return uid;
}

function purchaseRef(purchaseToken) {
  const tokenId = createHash("sha256").update(purchaseToken).digest("hex");
  return db.collection("usedPurchaseTokens").doc(tokenId);
}

exports.ensureUserProfile = onCall({ region: FUNCTIONS_REGION }, async (request) => {
  const uid = requireUser(request);
  const ref = userRef(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      tx.set(ref, { coins: 20, createdAt: FieldValue.serverTimestamp() });
      return { coins: 20 };
    }
    return { coins: Number(snap.data()?.coins ?? 0) };
  });
});

exports.getCoins = onCall({ region: FUNCTIONS_REGION }, async (request) => {
  const uid = requireUser(request);
  const snap = await userRef(uid).get();
  return { coins: Number(snap.data()?.coins ?? 0) };
});

exports.spendCoin = onCall({ region: FUNCTIONS_REGION }, async (request) => {
  const uid = requireUser(request);
  const ref = userRef(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const coins = Number(snap.data()?.coins ?? 0);
    if (coins <= 0) return { success: false, coins: 0 };
    const nextCoins = coins - 1;
    if (snap.exists) {
      tx.update(ref, { coins: nextCoins });
    } else {
      tx.set(ref, { coins: nextCoins, createdAt: FieldValue.serverTimestamp() });
    }
    return { success: true, coins: nextCoins };
  });
});

exports.getSubscriptionStatus = onCall({ region: FUNCTIONS_REGION }, async (request) => {
  const uid = requireUser(request);
  const data = (await userRef(uid).get()).data() ?? {};
  const expiry = data.subscriptionExpiresAt?.toDate?.() ?? null;
  const active = data.subscriptionActive === true && (!expiry || expiry.getTime() > Date.now());
  return {
    active,
    expiresAt: expiry?.toISOString() ?? null,
    coins: Number(data.coins ?? 0),
  };
});

exports.verifyGooglePlayPurchase = onCall({
  region: FUNCTIONS_REGION,
  secrets: ["GOOGLE_SERVICE_ACCOUNT_JSON"],
}, async (request) => {
  const uid = requireUser(request);
  const { productId, purchaseToken } = request.data ?? {};
  if (!productId || !purchaseToken) {
    throw new HttpsError("invalid-argument", "productId and purchaseToken required.");
  }
  if (![TOP_UP_PRODUCT_ID, WEEKLY_PRODUCT_ID].includes(productId)) {
    throw new HttpsError("invalid-argument", "Unknown Google Play product.");
  }

  try {
    const credentials = JSON.parse(process.env.GOOGLE_SERVICE_ACCOUNT_JSON);
    const auth = new google.auth.GoogleAuth({
      credentials,
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    const androidpublisher = google.androidpublisher({ version: "v3", auth });
    let coins = 0;
    let subscriptionExpiresAt = null;

    if (productId === WEEKLY_PRODUCT_ID) {
      const response = await androidpublisher.purchases.subscriptionsv2.get({
        packageName: PACKAGE_NAME,
        token: purchaseToken,
      });
      const state = response.data?.subscriptionState;
      if (!["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"].includes(state)) {
        throw new HttpsError("failed-precondition", "Subscription is not active.");
      }
      const lineItem = (response.data?.lineItems ?? []).find((item) => item.productId === productId);
      if (!lineItem?.expiryTime) {
        throw new HttpsError("failed-precondition", "Subscription expiry is unavailable.");
      }
      subscriptionExpiresAt = new Date(lineItem.expiryTime);
      if (Number.isNaN(subscriptionExpiresAt.getTime())) {
        throw new HttpsError("failed-precondition", "Subscription expiry is invalid.");
      }
      coins = COINS_PER_WEEK;
    } else {
      const response = await androidpublisher.purchases.products.get({
        packageName: PACKAGE_NAME,
        productId,
        token: purchaseToken,
      });
      if (Number(response.data?.purchaseState) !== 0) {
        throw new HttpsError("failed-precondition", "Purchase is not completed.");
      }
      coins = COINS_PER_TOPUP;
    }

    const ref = userRef(uid);
    const usedToken = purchaseRef(purchaseToken);
    const result = await db.runTransaction(async (tx) => {
      const usedSnap = await tx.get(usedToken);
      const profileSnap = await tx.get(ref);
      const currentCoins = Number(profileSnap.data()?.coins ?? 0);

      if (usedSnap.exists) {
        if (productId !== WEEKLY_PRODUCT_ID) {
          throw new HttpsError("already-exists", "Purchase already applied.");
        }
        tx.set(ref, {
          subscriptionActive: true,
          subscriptionExpiresAt: Timestamp.fromDate(subscriptionExpiresAt),
        }, { merge: true });
        return { coins: currentCoins, subscriptionActive: true };
      }

      const updates = { coins: FieldValue.increment(coins) };
      if (productId === WEEKLY_PRODUCT_ID) {
        updates.subscriptionActive = true;
        updates.subscriptionExpiresAt = Timestamp.fromDate(subscriptionExpiresAt);
        updates.subscriptionProductId = productId;
      }
      tx.set(ref, updates, { merge: true });
      tx.create(usedToken, {
        uid,
        productId,
        usedAt: FieldValue.serverTimestamp(),
      });
      return {
        coins: currentCoins + coins,
        subscriptionActive: productId === WEEKLY_PRODUCT_ID,
      };
    });

    return {
      coins: result.coins,
      subscriptionActive: result.subscriptionActive ?? false,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("Google Play purchase verification failed", error);
    throw new HttpsError("internal", "Could not verify purchase with Google Play.");
  }
});
