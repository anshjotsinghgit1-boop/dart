import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

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
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is not set. Add it as a GitHub Secret.');
    }

    final url = Uri.parse('$_baseUrl?key=$_apiKey');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': _systemPrompt(mood)}
          ]
        },
        'contents': [
          {
            'parts': [
              {'text': 'Reply to this message: "$message"'}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.85,
          'maxOutputTokens': 150,
          'topP': 0.95,
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final reply = data['candidates'][0]['content']['parts'][0]['text']
          .toString()
          .trim();
      // Remove any wrapping quotes the model may add
      String cleaned = reply.trim();
if (cleaned.length >= 2 &&
    ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
     (cleaned.startsWith("'") && cleaned.endsWith("'")))) {
  cleaned = cleaned.substring(1, cleaned.length - 1);
}
return cleaned;
    } else if (response.statusCode == 400) {
      throw Exception('Bad request. Check API key or prompt.');
    } else if (response.statusCode == 429) {
      throw Exception('Rate limit hit. Wait a moment and try again.');
    } else {
      throw Exception('Gemini error ${response.statusCode}: ${response.body}');
    }
  }
}
