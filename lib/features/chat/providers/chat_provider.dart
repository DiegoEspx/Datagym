import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/groq_service.dart';
import '../services/gemma_service.dart';
import '../services/chat_context_builder.dart';

enum ChatMode { online, offline, unknown }

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final ChatMode mode;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.mode = ChatMode.unknown,
  });
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final ChatMode currentMode;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.currentMode = ChatMode.unknown,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    ChatMode? currentMode,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      currentMode: currentMode ?? this.currentMode,
    );
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(ChatState());

  final _groqService = GroqService();
  final _gemmaService = GemmaService();

  Future<ChatMode> _detectMode() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result.contains(ConnectivityResult.none)) {
        return ChatMode.offline;
      }
      return ChatMode.online;
    } catch (_) {
      return ChatMode.offline;
    }
  }

  Future<void> sendMessage(String userMessage) async {
    final userMsg = ChatMessage(
      text: userMessage,
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
    );

    try {
      final mode = await _detectMode();
      final context = await ChatContextBuilder.buildSystemPrompt();

      String response;

      if (mode == ChatMode.online) {
        response = await _groqService.sendMessage(
          userMessage: userMessage,
          systemContext: context,
        );
      } else {
        final fullPrompt = '$context\n\nUsuario: $userMessage\nAsistente:';
        response = await _gemmaService.sendMessage(fullPrompt);
      }

      final assistantMsg = ChatMessage(
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
        mode: mode,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
        currentMode: mode,
      );
    } catch (_) {
      final errorMsg = ChatMessage(
        text: 'No pude responder en este momento. Intenta de nuevo.',
        isUser: false,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
      );
    }
  }

  void clearMessages() {
    state = ChatState();
  }
}
