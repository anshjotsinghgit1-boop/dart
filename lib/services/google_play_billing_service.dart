import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

class GooglePlayBillingService {
  static const String topUpProductId = 'coins_150_100';
  static const String weeklyProductId = 'rizz_weekly';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  final void Function(int coins)? onCoinsUpdated;
  final void Function(String message)? onError;
  final void Function(String productId)? onPurchaseStarted;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  final Map<String, ProductDetails> _products = {};

  GooglePlayBillingService({
    this.onCoinsUpdated,
    this.onError,
    this.onPurchaseStarted,
  });

  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      onError?.call('Google Play Billing is available only on Android.');
      return;
    }

    final available = await _inAppPurchase.isAvailable();

    if (!available) {
      onError?.call('Google Play Billing is not available.');
      return;
    }

    _purchaseSubscription =
        _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        onError?.call('Purchase stream error: $error');
      },
    );

    final response = await _inAppPurchase.queryProductDetails({
      topUpProductId,
      weeklyProductId,
    });

    if (response.error != null) {
      onError?.call(
        response.error?.message ?? 'Could not load Google Play products.',
      );
      return;
    }

    if (response.notFoundIDs.isNotEmpty) {
      onError?.call(
        'These products were not found in Google Play Console: '
        '${response.notFoundIDs.join(', ')}',
      );
    }

    for (final product in response.productDetails) {
      _products[product.id] = product;
    }
  }

  ProductDetails? product(String productId) {
    return _products[productId];
  }

  String? price(String productId) {
    return _products[productId]?.price;
  }

  Future<void> buyTopUp() async {
    await _buy(topUpProductId, consumable: true);
  }

  Future<void> buyWeeklyPlan() async {
    await _buy(weeklyProductId, consumable: false);
  }

  Future<void> _buy(
    String productId, {
    required bool consumable,
  }) async {
    final productDetails = _products[productId];

    if (productDetails == null) {
      onError?.call(
        'Product is not available yet. Please try again.',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      onError?.call('Please log in before purchasing.');
      return;
    }

    PurchaseParam purchaseParam = PurchaseParam(
      productDetails: productDetails,
    );

    if (Platform.isAndroid &&
        productDetails is GooglePlayProductDetails) {
      final obfuscatedProfileId = sha256
          .convert(utf8.encode(user.uid))
          .toString();

      purchaseParam = GooglePlayPurchaseParam(
        productDetails: productDetails,
        offerToken: productDetails.offerToken,
        obfuscatedProfileId: obfuscatedProfileId,
      );
    }

    onPurchaseStarted?.call(productId);

    if (consumable) {
      // Google Play consumption is performed by the backend
      // only after the purchase has been verified and credited.
      await _inAppPurchase.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: false,
      );
    } else {
      await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        onError?.call(
          purchase.error?.message ?? 'Google Play purchase failed.',
        );
        continue;
      }

      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        continue;
      }

      final purchaseToken =
          purchase.verificationData.serverVerificationData;

      if (purchaseToken.isEmpty) {
        onError?.call('Google Play returned an empty purchase token.');
        continue;
      }

      try {
        final functions = FirebaseFunctions.instanceFor(
          region: 'asia-south1',
        );

        final result = await functions
            .httpsCallable('verifyGooglePlayPurchase')
            .call({
          'productId': purchase.productID,
          'purchaseToken': purchaseToken,
        });

        final data = Map<String, dynamic>.from(
          result.data as Map,
        );

        final coins = (data['coins'] as num?)?.toInt();

        if (coins != null) {
          onCoinsUpdated?.call(coins);
        }

        // Complete only after the backend has verified and delivered
        // the purchase. If verification fails, Google will resend it.
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
      } on FirebaseFunctionsException catch (e) {
        onError?.call(
          e.message ?? 'The purchase could not be verified.',
        );
      } catch (e) {
        onError?.call(
          'The purchase could not be verified: $e',
        );
      }
    }
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
  }
}
