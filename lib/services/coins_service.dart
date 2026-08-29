import 'package:cloud_functions/cloud_functions.dart';

class CoinsService {
  static const String functionsRegion = 'asia-south1';

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: functionsRegion,
  );

  static Future<int> ensureProfile() async {
    final result = await _functions
        .httpsCallable('ensureUserProfile')
        .call();

    return _coinsFromResult(result.data);
  }

  static Future<int> getCoins() async {
    return ensureProfile();
  }

  static Future<bool> spendCoin() async {
    final result = await _functions
        .httpsCallable('spendCoin')
        .call();

    final data = Map<String, dynamic>.from(result.data as Map);
    return data['success'] == true;
  }

  static int _coinsFromResult(Object? rawData) {
    final data = Map<String, dynamic>.from(rawData as Map);
    return (data['coins'] as num?)?.toInt() ?? 0;
  }
}
