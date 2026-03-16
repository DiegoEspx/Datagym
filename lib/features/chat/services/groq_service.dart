import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GroqService {
  final String _apiKey = dotenv.get('GROQ_API_KEY', fallback: '');
  final String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  Future<String> sendMessage({
    required String userMessage,
    required String systemContext,
  }) async {
    if (_apiKey.isEmpty) {
      return "Error: No se encontró la API Key de Groq. Configura tu archivo .env";
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {'role': 'system', 'content': systemContext},
            {'role': 'user', 'content': userMessage},
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      }

      return "Error del servidor (${response.statusCode}): ${response.body}";
    } catch (e) {
      return "Error de red: $e";
    }
  }
}
