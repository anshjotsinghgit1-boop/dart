import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class SubscriptionService {
  static const _projectId = 'replyai-749f7';
  static const _database = 'databaseforrizzaj';

  static Future<bool> hasActiveSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final token = await user.getIdToken();
      final url =
          'https://firestore.googleapis.com/v1/projects/$_projectId/databases/$_database/documents/users/${user.uid}';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body);
      final fields = data['fields'] as Map<String, dynamic>?;
      if (fields == null) return false;

      final activeField = fields['subscriptionActive'];
      final isActive = activeField?['booleanValue'] == true;
      if (!isActive) return false;

      final expiresField = fields['subscriptionExpiresAt'];
      if (expiresField != null) {
        final expiresStr = expiresField['timestampValue'] as String?;
        if (expiresStr != null) {
          final expires = DateTime.tryParse(expiresStr);
          if (expires != null && DateTime.now().isAfter(expires)) {
            return false;
          }
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
