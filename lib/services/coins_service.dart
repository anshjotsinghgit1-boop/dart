import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class CoinsService {
  static const _project = 'replyai-749f7';
  static const _base = 'https://firestore.googleapis.com/v1';

  static User get _user {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw StateError('Not logged in.');
    return u;
  }

  static Future<String> _token() async =>
      await _user.getIdToken(true) ?? '';

  static String get _docUrl =>
      '$_base/projects/$_project/databases/(default)/documents/users/${_user.uid}';

  static Future<int> ensureProfile() async {
    final token = await _token();
    final res = await http.get(
      Uri.parse(_docUrl),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final fields = (jsonDecode(res.body)['fields'] as Map?) ?? {};
      final val = fields['coins']?['integerValue'];
      return int.tryParse(val?.toString() ?? '0') ?? 0;
    }

    if (res.statusCode == 404) {
      // New user — create with 20 coins
      final create = await http.patch(
        Uri.parse(_docUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fields': {
            'coins': {'integerValue': '20'},
            'createdAt': {'stringValue': DateTime.now().toIso8601String()},
          }
        }),
      );
      if (create.statusCode == 200) return 20;
    }

    throw Exception('Firestore REST error ${res.statusCode}: ${res.body}');
  }

  static Future<int> getCoins() async {
    try {
      return await ensureProfile();
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> spendCoin() async {
    try {
      final token = await _token();
      final res = await http.get(
        Uri.parse(_docUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) return false;

      final fields = (jsonDecode(res.body)['fields'] as Map?) ?? {};
      final coins = int.tryParse(
            fields['coins']?['integerValue']?.toString() ?? '0') ?? 0;
      if (coins <= 0) return false;

      final patch = await http.patch(
        Uri.parse('$_docUrl?updateMask.fieldPaths=coins'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fields': {
            'coins': {'integerValue': '${coins - 1}'},
          }
        }),
      );
      return patch.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<int> addCoins(int amount) async {
    try {
      final token = await _token();
      final res = await http.get(
        Uri.parse(_docUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      int current = 0;
      if (res.statusCode == 200) {
        final fields = (jsonDecode(res.body)['fields'] as Map?) ?? {};
        current = int.tryParse(
              fields['coins']?['integerValue']?.toString() ?? '0') ?? 0;
      }

      final newCoins = current + amount;
      await http.patch(
        Uri.parse('$_docUrl?updateMask.fieldPaths=coins'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fields': {
            'coins': {'integerValue': '$newCoins'},
          }
        }),
      );
      return newCoins;
    } catch (_) {
      return 0;
    }
  }
}
