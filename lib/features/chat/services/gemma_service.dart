import 'package:flutter_gemma/flutter_gemma.dart';

class GemmaService {
  static final GemmaService _instance = GemmaService._internal();
  factory GemmaService() => _instance;
  GemmaService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await FlutterGemmaPlugin.instance.init(
        maxTokens: 512,
        temperature: 0.7,
        topK: 40,
        randomSeed: 42,
      );
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  Future<String> sendMessage(String prompt) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final response = await FlutterGemmaPlugin.instance.getResponse(
        prompt: prompt,
      );
      return response ?? 'No pude generar una respuesta.';
    } catch (e) {
      return 'Error al procesar tu pregunta sin conexión: $e';
    }
  }

  bool get isInitialized => _isInitialized;
}
