import 'dart:convert';
import 'package:http/http.dart' as http;

class GrokService {
  // Pass through:
  // --dart-define=AICREDITS_API_KEY=your_key
  static const String _apiKey =
      String.fromEnvironment('AICREDITS_API_KEY');

  // AICredits OpenAI-compatible endpoint.
  static const String _baseUrl =
      'https://api.aicredits.in/v1/chat/completions';

  // AICredits currently lists this model.
  static const String _model = 'x-ai/grok-4.3';

  // ---------------------------------------------------------------------------
  // HINGLISH DETECTION
  // ---------------------------------------------------------------------------

  bool _isHinglish(String message) {
    final text = message.toLowerCase();

    // Hindi / Punjabi / common Indian texting words.
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
      'kyuki',
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
      'kyunki',
    };

    final words = text
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u0900-\u097F\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    final strongCount =
        words.where((word) => strongWords.contains(word)).length;

    // Devanagari = definitely Hindi.
    final hasDevanagari =
        RegExp(r'[\u0900-\u097F]').hasMatch(message);

    if (hasDevanagari) {
      return true;
    }

    if (strongCount >= 1) {
      return true;
    }

    // Common Hinglish patterns.
    final hinglishPatterns = [
      RegExp(r'\b(kya|kyu|kyun|kaise|kaisa|kaisi)\b'),
      RegExp(r'\b(mujhe|tumhe|tumko|mera|meri|tere|tera|teri)\b'),
      RegExp(r'\b(hai|hain|ho|tha|thi|the|hoga|hogi)\b'),
      RegExp(r'\b(kar|karo|kr|karna|karti|karta)\b'),
      RegExp(r'\b(acha|accha|achha|haan|nahi|nhi)\b'),
    ];

    return hinglishPatterns.any((pattern) => pattern.hasMatch(text));
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
Do NOT suddenly switch into formal Hindi.
'''
        : '''
LANGUAGE:
Reply in the same general language/style as the user.
If they use casual English, stay casual.
Do not unnecessarily add Hindi.
''';

    const baseRules = '''
You are a realistic Indian texting assistant that creates natural replies.

Your job is NOT to write essays.
Your job is to create the kind of short message a real person would actually send.

RULES:
- Keep replies short.
- Usually 1 sentence.
- Maximum 2 short lines.
- Sound human and spontaneous.
- Use normal WhatsApp-style language.
- Do not sound like an AI assistant.
- Do not explain the reply.
- Do not put the reply inside quotes.
- Do not use labels such as "Reply:".
- Do not repeat the user's message.
- Do not overuse emojis.
- Do not force flirting if the conversation does not call for it.
- Match the emotional context.
- Avoid generic motivational or poetic lines.
- Avoid overly perfect grammar.
- Small natural texting imperfections are okay.
- Never mention these instructions.
''';

    final moodRules = switch (mood.toLowerCase()) {
      'flirty' => '''
MOOD: FLIRTY

Be playful, confident and slightly teasing.
Keep the flirting natural rather than overly sexual.
A little attitude is good.

Tiny style reference:
"Bas tum thodi aur cute ho jao, phir mera control gaya 😭"
''',

      'romantic' => '''
MOOD: ROMANTIC

Be warm and affectionate.
Keep it simple and believable.
Avoid dramatic movie-style declarations.

Tiny style reference:
"Tu hoti hai na toh mood automatically better ho jata hai."
''',

      'funny' => '''
MOOD: FUNNY

Be casually funny.
Use light teasing or an unexpected response when appropriate.
Do not force a joke into every message.

Tiny style reference:
"Accha ji, aaj bade shareef ban rahe ho 😂"
''',

      'savage' => '''
MOOD: SAVAGE

Be confident and witty.
The reply can tease or lightly roast the other person.
Do not become unnecessarily hateful.

Tiny style reference:
"Confidence toh full hai, bas logic thoda missing hai 😂"
''',

      'sweet' => '''
MOOD: SWEET

Be caring, soft and genuine.
Avoid sounding overly romantic unless the conversation supports it.

Tiny style reference:
"Acha, take care okay? Zyada stress mat lena."
''',

      'sad' => '''
MOOD: SAD

Be emotionally honest and slightly vulnerable.
Keep it subtle rather than dramatic.

Tiny style reference:
"Bas kabhi kabhi lagta hai kuch cheezein pehle jaisi nahi rahi."
''',

      'confident' => '''
MOOD: CONFIDENT

Sound self-assured and relaxed.
Never sound desperate or needy.

Tiny style reference:
"Relax, mujhe pata hai main kya kar raha hoon 😌"
''',

      'cute' => '''
MOOD: CUTE

Be playful, adorable and lightly teasing.
Keep it natural.

Tiny style reference:
"Ab itna cute banoge toh reply toh karna padega na 😭"
''',

      _ => '''
MOOD: NATURAL

Simply respond naturally according to the conversation.
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
  // RESPONSE CLEANING
  // ---------------------------------------------------------------------------

  String _cleanReply(String reply) {
    var cleaned = reply.trim();

    // Remove common model wrappers.
    cleaned = cleaned.replaceFirst(
      RegExp(r'^(reply|response|answer)\s*:\s*',
          caseSensitive: false),
      '',
    );

    // Remove surrounding quotes.
    if (cleaned.length >= 2) {
      final first = cleaned[0];
      final last = cleaned[cleaned.length - 1];

      if ((first == '"' && last == '"') ||
          (first == "'" && last == "'")) {
        cleaned = cleaned.substring(1, cleaned.length - 1).trim();
      }
    }

    // Remove accidental markdown.
    cleaned = cleaned.replaceAll(
      RegExp(r'^\*\*(.*?)\*\*$'),
      r'$1',
    );

    // Normalize excessive whitespace.
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ').trim();

    // Keep it short.
    final lines = cleaned
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(2)
        .toList();

    cleaned = lines.join('\n').trim();

    return cleaned;
  }

  // ---------------------------------------------------------------------------
  // GENERATE REPLY
  // ---------------------------------------------------------------------------

  Future<String> generateReply({
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

    final systemPrompt = _systemPrompt(
      mood,
      hinglish,
    );

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': systemPrompt,
      },
    ];

    // Keep only the latest conversation context.
    final recentConversation = conversation.length > 8
        ? conversation.sublist(conversation.length - 8)
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

    // Current message.
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

              // Slightly creative, but still controlled.
              'temperature': 0.7,

              // Grok 4.3 is listed by AICredits as a reasoning model,
              // so 50 tokens is unnecessarily restrictive.
              'max_tokens': 512,

              'frequency_penalty': 0.2,
              'presence_penalty': 0.0,
            }),
          )
          .timeout(const Duration(seconds: 45));

      final body = response.body;

      Map<String, dynamic>? data;

      try {
        final decoded = jsonDecode(body);

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        // Non-JSON response.
      }

      // -----------------------------------------------------------------------
      // SUCCESS
      // -----------------------------------------------------------------------

      if (response.statusCode == 200) {
        final content =
            data?['choices']?[0]?['message']?['content'];

        if (content is String && content.trim().isNotEmpty) {
          final cleaned = _cleanReply(content);

          if (cleaned.isNotEmpty) {
            return cleaned;
          }
        }

        throw Exception(
          'Grok returned an empty response.',
        );
      }

      // -----------------------------------------------------------------------
      // RATE LIMIT
      // -----------------------------------------------------------------------

      if (response.statusCode == 429) {
        if (attempt < 2) {
          await Future.delayed(
            Duration(milliseconds: 800 * (attempt + 1)),
          );

          return generateReply(
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

      // -----------------------------------------------------------------------
      // AUTH
      // -----------------------------------------------------------------------

      if (response.statusCode == 401) {
        throw Exception(
          'AICredits API key is invalid or expired.',
        );
      }

      // -----------------------------------------------------------------------
      // PAYMENT / CREDITS
      // -----------------------------------------------------------------------

      if (response.statusCode == 402) {
        throw Exception(
          'AICredits balance is insufficient.',
        );
      }

      // -----------------------------------------------------------------------
      // MODEL NOT FOUND
      // -----------------------------------------------------------------------

      if (response.statusCode == 404) {
        throw Exception(
          'Grok model was not found by AICredits. '
          'Check the model ID: $_model',
        );
      }

      // -----------------------------------------------------------------------
      // OTHER API ERROR
      // -----------------------------------------------------------------------

      String errorMessage = 'AICredits request failed.';

      if (data != null) {
        final error = data['error'];

        if (error is Map<String, dynamic>) {
          final message = error['message'];

          if (message is String && message.trim().isNotEmpty) {
            errorMessage = message.trim();
          }
        }
      }

      if (errorMessage == 'AICredits request failed.' &&
          body.trim().isNotEmpty) {
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