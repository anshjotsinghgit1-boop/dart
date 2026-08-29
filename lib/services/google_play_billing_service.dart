import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

class GooglePlayBillingService {
  static const String topUpProductId = 'coins_150_100';
  static const String weeklyProductId = 'rizz_weekly';
  static const String functionsRegion = 'asia-south1';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: functionsRegion,
  );

  final void Function(String productId, int coins)? onPurchaseCompleted;
  final void Function(String message)? onError;
  final void Function(String productId)? onPurchaseStarted;
  final VoidCallback? onPurchasePending;
  final VoidCallback? onPurchaseCancelled;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final Map<String, ProductDetails> _products = {};
  bool _initialized = false;

  GooglePlayBillingService({
    this.onPurchaseCompleted,
    this.onError,
    this.onPurchaseStarted,
    this.onPurchasePending,
    this.onPurchaseCancelled,
  });

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (_initialized) return;

    if (!_isAndroid) {
      onError?.call('Google Play Billing is available only on Android.');
      return;
    }

    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      onError?.call('Google Play Billing is not available.');
      return;
    }

    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
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
        'Products not found in Google Play Console: ' +
        response.notFoundIDs.join(', '),
      );
    }

    for (final product in response.productDetails) {
      _products[product.id] = product;
    }

    _initialized = true;
  }

  ProductDetails? product(String productId) => _products[productId];

  String? price(String productId) => _products[productId]?.price;

  Future<void> buyTopUp() async {
    await _buy(topUpProductId, consumable: true);
  }

  Future<void> buyWeeklyPlan() async {
    await _buy(weeklyProductId, consumable: false);
  }

  Future<void> restorePurchases() async {
    if (!_isAndroid) return;
    await _inAppPurchase.restorePurchases();
  }

  Future<void> _buy(
    String productId, {
    required bool consumable,
  }) async {
    final productDetails = _products[productId];

    if (productDetails == null) {
      onError?.call('Product not available yet. Please try again.');
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      onError?.call('Please log in before purchasing.');
      return;
    }

    onPurchaseStarted?.call(productId);

    final purchaseParam = _isAndroid &&
            productDetails is GooglePlayProductDetails
        ? GooglePlayPurchaseParam(productDetails: productDetails)
        : PurchaseParam(productDetails: productDetails);

    final started = consumable
        ? await _inAppPurchase.buyConsumable(
            purchaseParam: purchaseParam,
            autoConsume: false,
          )
        : await _inAppPurchase.buyNonConsumable(
            purchaseParam: purchaseParam,
          );

    if (!started) {
      onError?.call('Google Play could not start the purchase.');
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          onPurchasePending?.call();
          continue;
        case PurchaseStatus.canceled:
          onPurchaseCancelled?.call();
          continue;
        case PurchaseStatus.error:
          onError?.call(
            purchase.error?.message ?? 'Google Play purchase failed.',
          );
          continue;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyWithServer(purchase);
          continue;
      }
    }
  }

  Future<void> _verifyWithServer(PurchaseDetails purchase) async {
    final purchaseToken =
        purchase.verificationData.serverVerificationData;

    if (purchaseToken.isEmpty) {
      onError?.call('Google Play returned an empty purchase token.');
      return;
    }

    try {
      final result = await _functions
          .httpsCallable('verifyGooglePlayPurchase')
          .call({
        'productId': purchase.productID,
        'purchaseToken': purchaseToken,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final coins = (data['coins'] as num?)?.toInt();

      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }

      if (coins != null) {
        onPurchaseCompleted?.call(purchase.productID, coins);
      }
    } on FirebaseFunctionsException catch (error) {
      onError?.call(
        error.message ?? 'The purchase could not be verified.',
      );
    } catch (_) {
      onError?.call('The purchase could not be verified.');
    }
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _initialized = false;
  }
}
