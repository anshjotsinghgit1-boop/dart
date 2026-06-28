import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  static const _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const _baseUrl = 'https://api.sambanova.ai/v1/chat/completions';

  static Future<String> generateReply({
    required String message,
    required String mood,
  }) async {
    final prompt = '''You are Rizz Guru, an expert at crafting perfect replies.
Generate a $mood reply to this message: "$message"

Rules:
- If the message is in Hindi/Hinglish, reply in Hinglish
- If the message is in English, reply in English
- Keep it natural and conversational
- Match the $mood vibe perfectly
- Reply with ONLY the reply text, nothing else''';

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'Meta-Llama-3.1-8B-Instruct',
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.9,
        'max_tokens': 200,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'].toString().trim();
    } else {
      throw Exception('Failed: ${response.body}');
    }
  }
}
