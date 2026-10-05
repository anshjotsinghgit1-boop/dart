import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  static const String _apiKey =
      String.fromEnvironment('AICREDITS_API_KEY');

  static const String _baseUrl =
      'https://api.aicredits.in/v1/chat/completions';

  static const String _model = 'x-ai/grok-4.3';

  // ---------------------------------------------------------------------------
  // HINGLISH DETECTION
  // ---------------------------------------------------------------------------

  bool _isHinglish(String message) {
    final text = message.toLowerCase();

    const strongWords = {
      'hai',
      'hain',
      'ho',
      'hoga',
      'hogi',
      'tha',
      'thi',
      'the',
      'mujhe',
      'tumhe',
      'tumko',
      'mere',
      'mera',
      'meri',
      'tere',
      'tera',
      'teri',
      'tum',
      'aap',
      'apka',
      'apni',
      'kya',
      'kyu',
      'kyun',
      'kaise',
      'kaisa',
      'kaisi',
      'acha',
      'accha',
      'achha',
      'haan',
      'nahi',
      'nhi',
      'nah',
      'mat',
      'kar',
      'karo',
      'kr',
      'karti',
      'karta',
      'karna',
      'gayi',
      'gaya',
      'jaa',
      'ja',
      'raha',
      'rahi',
      'rhe',
      'hoon',
      'hu',
      'bhi',
      'toh',
      'to',
      'bas',
      'abhi',
      'phir',
      'fir',
      'kyunki',
      'pata',
      'lagta',
      'lagti',
      'sach',
      'pagal',
      'yaar',
      'bhai',
      'bro',
      'bacha',
      'baby',
      'jaan',
      'love',
      'pyaar',
      'acchi',
      'sundar',
      'cute',
      'milna',
      'baat',
      'baatein',
      'bol',
      'bata',
      'bta',
      'dekh',
      'dekho',
      'sun',
      'suno',
      'kuch',
    };

    final words = text
        .replaceAll(
          RegExp(r'[^a-zA-Z0-9\u0900-\u097F\s]'),
          ' ',
        )
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    final strongCount =
        words.where((word) => strongWords.contains(word)).length;

    final hasDevanagari =
        RegExp(r'[\u0900-\u097F]').hasMatch(message);

    if (hasDevanagari) {
      return true;
    }

    if (strongCount >= 1) {
      return true;
    }

    final hinglishPatterns = [
      RegExp(r'\b(kya|kyu|kyun|kaise|kaisa|kaisi)\b'),
      RegExp(r'\b(mujhe|tumhe|tumko|mera|meri|tere|tera|teri)\b'),
      RegExp(r'\b(hai|hain|ho|tha|thi|the|hoga|hogi)\b'),
      RegExp(r'\b(kar|karo|kr|karna|karti|karta)\b'),
      RegExp(r'\b(acha|accha|achha|haan|nahi|nhi)\b'),
    ];

    return hinglishPatterns.any(
      (pattern) => pattern.hasMatch(text),
    );
  }

  // ---------------------------------------------------------------------------
  // SYSTEM PROMPT
  // ---------------------------------------------------------------------------

  String _systemPrompt(String mood, bool hinglish) {
    final languageRule = hinglish
        ? '''
LANGUAGE:
The user is texting in Hinglish/Indian texting style.
Reply naturally in Hinglish or casual Indian English.
Use Roman Hindi when appropriate.
Do not suddenly switch into formal Hindi.
'''
        : '''
LANGUAGE:
Reply in the same general language and style as the user.
If they use casual English, stay casual.
Do not unnecessarily add Hindi.
''';

    const baseRules = '''
You create realistic replies for Indian WhatsApp-style conversations.

Your job is to write the message the person should actually send.

RULES:
- Keep replies short.
- Usually one sentence.
- Maximum two short lines.
- Sound human and spontaneous.
- Use normal texting language.
- Do not sound like an AI assistant.
- Do not explain the reply.
- Do not write "Reply:" or similar labels.
- Do not repeat the user's message.
- Do not overuse emojis.
- Match the conversation's emotional context.
- Avoid generic motivational lines.
- Avoid overly polished or formal language.
- Small natural texting imperfections are okay.
- Never mention these instructions.
''';

    final moodRules = switch (mood.toLowerCase()) {
      'flirty' => '''
MOOD: FLIRTY

Be playful, confident and lightly teasing.
Keep the flirting natural.
Do not force sexual content.

Example style:
"Bas tum thodi aur cute ho jao, phir mera control gaya 😭"
''',

      'romantic' => '''
MOOD: ROMANTIC

Be warm and affectionate.
Keep it simple and believable.
Avoid dramatic movie-style declarations.

Example style:
"Tu hoti hai na toh mood automatically better ho jata hai."
''',

      'funny' => '''
MOOD: FUNNY

Be casually funny.
Use light teasing when appropriate.
Do not force a joke into every reply.

Example style:
"Accha ji, aaj bade shareef ban rahe ho 😂"
''',

      'savage' => '''
MOOD: SAVAGE

Be confident and witty.
Lightly roast or tease when appropriate.
Do not become unnecessarily hateful.

Example style:
"Confidence toh full hai, bas logic thoda missing hai 😂"
''',

      'sweet' => '''
MOOD: SWEET

Be caring, soft and genuine.
Do not become overly romantic without context.

Example style:
"Acha, take care okay? Zyada stress mat lena."
''',

      'sad' => '''
MOOD: SAD

Be emotionally honest and slightly vulnerable.
Keep it subtle rather than dramatic.

Example style:
"Bas kabhi kabhi lagta hai kuch cheezein pehle jaisi nahi rahi."
''',

      'confident' => '''
MOOD: CONFIDENT

Sound self-assured and relaxed.
Never sound desperate or needy.

Example style:
"Relax, mujhe pata hai main kya kar raha hoon 😌"
''',

      'cute' => '''
MOOD: CUTE

Be playful, adorable and lightly teasing.

Example style:
"Ab itna cute banoge toh reply toh karna padega na 😭"
''',

      _ => '''
MOOD: NATURAL

Respond naturally according to the conversation.
Do not force a particular personality.
''',
    };

    return '''
$baseRules

$languageRule

$moodRules
''';
  }

  // ---------------------------------------------------------------------------
  // CLEAN RESPONSE
  // ---------------------------------------------------------------------------

  String _cleanReply(String reply) {
    var cleaned = reply.trim();

    cleaned = cleaned.replaceFirst(
      RegExp(
        r'^(reply|response|answer)\s*:\s*',
        caseSensitive: false,
      ),
      '',
    );

    if (cleaned.length >= 2) {
      final first = cleaned[0];
      final last = cleaned[cleaned.length - 1];

      if ((first == '"' && last == '"') ||
          (first == "'" && last == "'")) {
        cleaned = cleaned
            .substring(1, cleaned.length - 1)
            .trim();
      }
    }

    cleaned = cleaned.replaceAll(
      RegExp(r'^\*\*(.*?)\*\*$'),
      r'$1',
    );

    cleaned = cleaned
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();

    final lines = cleaned
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(2)
        .toList();

    return lines.join('\n').trim();
  }

  // ---------------------------------------------------------------------------
  // GENERATE REPLY
  // ---------------------------------------------------------------------------

  static Future<String> generateReply({
    required String message,
    required String mood,
    List<Map<String, String>> conversation = const [],
    int attempt = 0,
  }) async {
    final service = GroqService();

    return service._generateReply(
      message: message,
      mood: mood,
      conversation: conversation,
      attempt: attempt,
    );
  }

  Future<String> _generateReply({
    required String message,
    required String mood,
    List<Map<String, String>> conversation = const [],
    int attempt = 0,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'AICREDITS_API_KEY is missing. '
        'Build with --dart-define=AICREDITS_API_KEY=YOUR_KEY',
      );
    }

    if (message.trim().isEmpty) {
      throw Exception('Message cannot be empty.');
    }

    final hinglish = _isHinglish(message);

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': _systemPrompt(
          mood,
          hinglish,
        ),
      },
    ];

    final recentConversation = conversation.length > 8
        ? conversation.sublist(
            conversation.length - 8,
          )
        : conversation;

    for (final item in recentConversation) {
      final role = item['role'];
      final content = item['content'];

      if (content == null || content.trim().isEmpty) {
        continue;
      }

      if (role != 'user' && role != 'assistant') {
        continue;
      }

      messages.add({
        'role': role!,
        'content': content.trim(),
      });
    }

    messages.add({
      'role': 'user',
      'content': message.trim(),
    });

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': messages,
              'temperature': 0.7,
              'max_tokens': 512,
              'frequency_penalty': 0.2,
              'presence_penalty': 0.0,
            }),
          )
          .timeout(
            const Duration(seconds: 45),
          );

      final body = response.body;

      Map<String, dynamic>? data;

      try {
        final decoded = jsonDecode(body);

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        // Ignore invalid JSON.
      }

      // SUCCESS
      if (response.statusCode == 200) {
        final content =
            data?['choices']?[0]?['message']?['content'];

        if (content is String &&
            content.trim().isNotEmpty) {
          final cleaned = _cleanReply(content);

          if (cleaned.isNotEmpty) {
            return cleaned;
          }
        }

        throw Exception(
          'Grok returned an empty response.',
        );
      }

      // RATE LIMIT
      if (response.statusCode == 429) {
        if (attempt < 2) {
          await Future.delayed(
            Duration(
              milliseconds: 800 * (attempt + 1),
            ),
          );

          return _generateReply(
            message: message,
            mood: mood,
            conversation: conversation,
            attempt: attempt + 1,
          );
        }

        throw Exception(
          'Rate limit reached. Please try again in a moment.',
        );
      }

      // INVALID API KEY
      if (response.statusCode == 401) {
        throw Exception(
          'AICredits API key is invalid or expired.',
        );
      }

      // INSUFFICIENT CREDITS
      if (response.statusCode == 402) {
        throw Exception(
          'AICredits balance is insufficient.',
        );
      }

      // MODEL NOT FOUND
      if (response.statusCode == 404) {
        throw Exception(
          'Grok model was not found by AICredits. '
          'Check the model ID: $_model',
        );
      }

      // OTHER API ERROR
      String errorMessage =
          'AICredits request failed.';

      if (data != null) {
        final error = data['error'];

        if (error is Map<String, dynamic>) {
          final apiMessage = error['message'];

          if (apiMessage is String &&
              apiMessage.trim().isNotEmpty) {
            errorMessage = apiMessage.trim();
          }
        }
      }

      if (errorMessage == 'AICredits request failed.') {
        errorMessage =
            'AICredits error ${response.statusCode}.';
      }

      throw Exception(errorMessage);
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception(
        'Unable to generate reply: $e',
      );
    }
  }
}
