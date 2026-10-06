import 'package:cloud_functions/cloud_functions.dart';

class AIReplyService {
  static const String functionsRegion = 'asia-south1';

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(
    region: functionsRegion,
  );

  /// Generate a reply using the secure server-side AI system.
  ///
  /// Tier costs:
  /// - basic: 1 coin
  /// - smart: 3 coins
  /// - premium: 6 coins
  ///
  /// Coins are reserved before the AI request and permanently
  /// deducted only when generation succeeds.
  static Future<Map<String, dynamic>> generateReply({
    required String tier,
    required String message,
    required String mood,
    List<Map<String, String>> conversation = const [],
  }) async {
    try {
      final result = await _functions
          .httpsCallable('generateReply')
          .call({
        'tier': tier.trim().toLowerCase(),
        'message': message.trim(),
        'mood': mood.trim(),
        'conversation': conversation,
      });

      if (result.data is! Map) {
        throw Exception(
          'Invalid response received from AI service.',
        );
      }

      final data = Map<String, dynamic>.from(
        result.data as Map,
      );

      final reply = data['reply'];

      if (reply is! String || reply.trim().isEmpty) {
        throw Exception(
          'AI service returned an empty reply.',
        );
      }

      return data;
    } on FirebaseFunctionsException catch (error) {
      throw Exception(
        _handleFirebaseFunctionsError(error),
      );
    } catch (error) {
      if (error is Exception) {
        rethrow;
      }

      throw Exception(
        'Failed to generate reply: $error',
      );
    }
  }

  static String _handleFirebaseFunctionsError(
    FirebaseFunctionsException error,
  ) {
    final message =
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Unknown error.';

    switch (error.code) {
      case 'resource-exhausted':
        return message;

      case 'invalid-argument':
        return message;

      case 'failed-precondition':
        return message;

      case 'unauthenticated':
        return 'Please log in first.';

      case 'internal':
        return message == 'Unknown error.'
            ? 'AI generation failed. Please try again.'
            : message;

      case 'deadline-exceeded':
        return 'AI request timed out. Please try again.';

      case 'unavailable':
        return 'AI service is temporarily unavailable. Please try again.';

      case 'not-found':
        return message;

      default:
        return message;
    }
  }
}