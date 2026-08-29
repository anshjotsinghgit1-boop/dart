import 'package:cloud_functions/cloud_functions.dart';

class CoinsService {
  static const String functionsRegion = 'asia-south1';
  static String lastDebug = ''; // Debug tracking

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: functionsRegion,
  );

  static Future<int> ensureProfile() async {
    try {
      final result = await _functions
          .httpsCallable('ensureUserProfile')
          .call();

      final coins = _coinsFromResult(result.data);
      lastDebug = 'Coins: $coins | Profile ensured';
      return coins;
    } catch (e) {
      lastDebug = 'Error: $e';
      return 0;
    }
  }

  static Future<int> getCoins() async {
    return ensureProfile();
  }

  static Future<bool> spendCoin() async {
    try {
      final result = await _functions
          .httpsCallable('spendCoin')
          .call();

      final data = Map<String, dynamic>.from(result.data as Map);
      final success = data['success'] == true;
      lastDebug = success ? 'Coin spent successfully' : 'Coin spend failed';
      return success;
    } catch (e) {
      lastDebug = 'Spend error: $e';
      return false;
    }
  }

  static int _coinsFromResult(Object? rawData) {
    final data = Map<String, dynamic>.from(rawData as Map);
    return (data['coins'] as num?)?.toInt() ?? 0;
  }
}
