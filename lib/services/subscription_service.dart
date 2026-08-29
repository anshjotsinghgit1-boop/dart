import 'package:cloud_functions/cloud_functions.dart';

class SubscriptionService {
  static const String functionsRegion = 'asia-south1';

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: functionsRegion,
  );

  static Future<bool> hasActiveSubscription() async {
    try {
      final result = await _functions
          .httpsCallable('getSubscriptionStatus')
          .call();

      final data = Map<String, dynamic>.from(result.data as Map);
      return data['active'] == true;
    } catch (_) {
      return false;
    }
  }
}
