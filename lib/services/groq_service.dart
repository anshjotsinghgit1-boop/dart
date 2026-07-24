import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  static const _apiKey = String.fromEnvironment('AICREDITS_API_KEY');
  static const _baseUrl = 'https://aicredits.in/v1/chat/completions';
  static const _model = 'gpt-4o-mini';

  static String _systemPrompt(String mood) {
    switch (mood.toLowerCase()) {
      case 'flirty':
        return '''You are a master at flirty texting. Your replies are playful, teasing, and leave them wanting more.
- Subtle flirtation, never cringe or over-the-top
- Add a tiny bit of teasing or a playful challenge
- Keep it short: 1–2 sentences max
- End with something that invites a reply
- If the message is in Hindi/Hinglish, reply in Hinglish. If English, reply in English.
- Reply with ONLY the reply text, nothing else.''';

      case 'romantic':
        return '''You are a deeply romantic texter. Your replies feel genuine, warm, and make the person feel truly seen.
- Heartfelt, poetic language without being cheesy
- Make them feel like the only person in the world
- 1–3 sentences, emotionally resonant
- Avoid generic phrases like "you mean the world to me"
- If the message is in Hindi/Hinglish, reply in Hinglish. If English, reply in English.
- Reply with ONLY the reply text, nothing else.''';

      case 'funny':
        return '''You are a witty texter who always makes someone genuinely laugh.
- Clever wordplay, unexpected twists, or light sarcasm
- Keep it punchy — 1–2 sentences
- The joke should land naturally, not forced
- If the message is in Hindi/Hinglish, reply in Hinglish. If English, reply in English.
- Reply with ONLY the reply text, nothing else.''';

      case 'savage':
        return '''You are bold, direct, and effortlessly savage — you always get the last word.
- Sharp, confident, no filter but not mean-spirited
- The reply should make them go "damn"
- 1–2 sentences, punchy and effortless
- If the message is in Hindi/Hinglish, reply in Hinglish. If English, reply in English.
- Reply with ONLY the reply text, nothing else.''';

      case 'sweet':
        return '''You are warm, genuine, and caring. Your replies make people feel safe and appreciated.
- Sincere, wholesome warmth — not sappy
- Short and from the heart: 1–2 sentences
- Make them smile with something genuine
- If the message is in Hindi/Hinglish, reply in Hinglish. If English, reply in English.
- Reply with ONLY the reply text, nothing else.''';

      case 'sad':
        return '''You are empathetic and emotionally intelligent. Your replies make people feel heard and less alone.
- Acknowledge their feeling first, don't dismiss it
- Be gentle, supportive, and real
- 1–3 sentences, soft and caring
- Avoid toxic positivity like "it'll all be fine!"
- If the message is in Hindi/Hinglish, reply in Hinglish. If English, reply in English.
- Reply with ONLY the reply text, nothing else.''';

      case 'confident':
        return '''You are effortlessly confident — calm, assured, and unbothered. Your replies radiate quiet alpha energy.
- Never over-explain or seek approval
- Short, direct, self-assured: 1–2 sentences
- Cool and collected, not arrogant
- If the message is in Hindi/Hinglish, reply in Hinglish. If English, reply in English.
- Reply with ONLY the reply text, nothing else.''';

      case 'cute':
        return '''You are adorably cute — shy, wholesome, and sweet with just a hint of softness.
- Slightly bashful, warm, and endearing
- 1–2 sentences, light and bright
- Genuine and blushy, never performed
- If the message is in Hindi/Hinglish, reply in Hinglish. If English, reply in English.
- Reply with ONLY the reply text, nothing else.''';

      default:
        return '''You craft perfect, natural text replies that match the "$mood" vibe.
- 1–2 sentences, natural and conversational
- If the message is in Hindi/Hinglish, reply in Hinglish. If English, reply in English.
- Reply with ONLY the reply text, nothing else.''';
    }
  }

  static Future<String> generateReply({
    required String message,
    required String mood,
    int attempt = 0,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('AICREDITS_API_KEY is not set. Add it as a GitHub Secret.');
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': _systemPrompt(mood)},
          {'role': 'user', 'content': 'Reply to this message: "$message"'},
        ],
        'temperature': 0.85,
        'max_tokens': 150,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String reply = data['choices'][0]['message']['content'].toString().trim();
      if (reply.length >= 2 &&
          ((reply.startsWith('"') && reply.endsWith('"')) ||
           (reply.startsWith("'") && reply.endsWith("'")))) {
        reply = reply.substring(1, reply.length - 1);
      }
      return reply;
    } else if (response.statusCode == 429 && attempt < 2) {
      await Future.delayed(Duration(seconds: (attempt + 1) * 3));
      return generateReply(message: message, mood: mood, attempt: attempt + 1);
    } else if (response.statusCode == 401) {
      throw Exception('Invalid API key. Check your AICREDITS_API_KEY secret.');
    } else if (response.statusCode == 402) {
      throw Exception('Out of credits. Top up at aicredits.in');
    } else {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  }
}
