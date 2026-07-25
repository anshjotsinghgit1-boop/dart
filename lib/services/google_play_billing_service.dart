import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

class GooglePlayBillingService {
  static const String topUpProductId = 'coins_150_100';
  static const String weeklyProductId = 'rizz_weekly';
  static const String functionsRegion = 'asia-south1';

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

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
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
        'Products not found in Google Play Console: '
        '${response.notFoundIDs.join(', ')}',
      );
    }

    for (final product in response.productDetails) {
      _products[product.id] = product;
    }
  }

  ProductDetails? product(String productId) => _products[productId];
  String? price(String productId) => _products[productId]?.price;

  Future<void> buyTopUp() async {
    await _buy(topUpProductId, consumable: true);
  }

  Future<void> buyWeeklyPlan() async {
    await _buy(weeklyProductId, consumable: false);
  }

  Future<void> _buy(String productId, {required bool consumable}) async {
    final productDetails = _products[productId];

    if (productDetails == null) {
      onError?.call('Product not available yet. Please try again.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onError?.call('Please log in before purchasing.');
      return;
    }

    onPurchaseStarted?.call(productId);

    final PurchaseParam purchaseParam;

    if (_isAndroid && productDetails is GooglePlayProductDetails) {
      purchaseParam = GooglePlayPurchaseParam(
        productDetails: productDetails,
      );
    } else {
      purchaseParam = PurchaseParam(productDetails: productDetails);
    }

    if (consumable) {
      await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
    } else {
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyWithServer(purchase);
          break;

        case PurchaseStatus.error:
          onError?.call(
            purchase.error?.message ?? 'An unknown purchase error occurred.',
          );
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          break;
      }
    }
  }

  Future<void> _verifyWithServer(PurchaseDetails purchase) async {
    try {
      int coins = 0;

      if (purchase.productID == weeklyProductId) {
        coins = 150;
      } else if (purchase.productID == topUpProductId) {
        coins = 150;
      }

      if (coins > 0) {
        await _addCoinsDirectly(coins);
      }

      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    } catch (error) {
      onError?.call('Could not complete purchase. Try again.');
    }
  }

  Future<void> _addCoinsDirectly(int coins) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'coins': FieldValue.increment(coins),
    });

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final updatedCoins = (snap.data()?['coins'] as num?)?.toInt() ?? 0;
    onCoinsUpdated?.call(updatedCoins);
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
  }
}
