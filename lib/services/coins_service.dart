import 'package:shared_preferences/shared_preferences.dart';

class CoinsService {
  static const _key = 'user_coins';
  static const int startingCoins = 20;

  static Future<int> getCoins() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_key)) {
      await prefs.setInt(_key, startingCoins);
      return startingCoins;
    }
    return prefs.getInt(_key) ?? 0;
  }

  static Future<bool> spendCoin() async {
    final coins = await getCoins();
    if (coins <= 0) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, coins - 1);
    return true;
  }

  static Future<void> addCoins(int amount) async {
    final coins = await getCoins();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, coins + amount);
  }
}
