const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { google } = require("googleapis");

initializeApp();
const db = getFirestore();

const PACKAGE_NAME = "com.prothon.rizzguru"; // ← change this
const COINS_PER_TOPUP = 150;
const COINS_PER_WEEK = 150;

// ─── 1. ENSURE USER PROFILE ─────────────────────────────────
exports.ensureUserProfile = onCall(
  { region: "asia-south1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Login required.");

    const ref = db.collection("users").doc(uid);
    const snap = await ref.get();

    if (!snap.exists) {
      await ref.set({ coins: 20, createdAt: FieldValue.serverTimestamp() });
      return { coins: 20 };
    }
    return { coins: snap.data().coins ?? 0 };
  }
);

// ─── 2. SPEND COIN ───────────────────────────────────────────
exports.spendCoin = onCall(
  { region: "asia-south1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Login required.");

    const ref = db.collection("users").doc(uid);
    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const coins = snap.data()?.coins ?? 0;
      if (coins <= 0) return { success: false };
      tx.update(ref, { coins: FieldValue.increment(-1) });
      return { success: true };
    });
    return result;
  }
);

// ─── 3. VERIFY GOOGLE PLAY PURCHASE ─────────────────────────
exports.verifyGooglePlayPurchase = onCall(
  { region: "asia-south1", secrets: ["GOOGLE_SERVICE_ACCOUNT_JSON"] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Login required.");

    const { productId, purchaseToken } = request.data ?? {};
    if (!productId || !purchaseToken)
      throw new HttpsError("invalid-argument", "productId and purchaseToken required.");

    // Block replay attacks
    const tokenRef = db.collection("usedPurchaseTokens").doc(purchaseToken);
    if ((await tokenRef.get()).exists)
      throw new HttpsError("already-exists", "Purchase already applied.");

    const credentials = JSON.parse(process.env.GOOGLE_SERVICE_ACCOUNT_JSON);
    const auth = new google.auth.GoogleAuth({
      credentials,
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    const androidpublisher = google.androidpublisher({ version: "v3", auth });

    try {
      let coins = 0;

      if (productId === "rizz_weekly") {
        const res = await androidpublisher.purchases.subscriptionsv2.get({
          packageName: PACKAGE_NAME,
          token: purchaseToken,
        });
        const state = res.data?.subscriptionState;
        if (state !== "SUBSCRIPTION_STATE_ACTIVE" && state !== "SUBSCRIPTION_STATE_IN_GRACE_PERIOD")
          throw new HttpsError("failed-precondition", "Subscription not active.");
        coins = COINS_PER_WEEK;
      } else {
        const res = await androidpublisher.purchases.products.get({
          packageName: PACKAGE_NAME,
          productId,
          token: purchaseToken,
        });
        if (res.data.purchaseState !== 0)
          throw new HttpsError("failed-precondition", "Purchase not completed.");
        coins = COINS_PER_TOPUP;
      }

      const userRef = db.collection("users").doc(uid);
      await db.runTransaction(async (tx) => {
        tx.set(tokenRef, { uid, productId, usedAt: FieldValue.serverTimestamp() });
        tx.update(userRef, { coins: FieldValue.increment(coins) });
      });

      const updated = await userRef.get();
      return { coins: updated.data()?.coins ?? 0 };

    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error(err);
      throw new HttpsError("internal", "Could not verify purchase.");
    }
  }
);
