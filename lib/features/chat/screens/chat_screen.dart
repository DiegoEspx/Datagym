import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await ref.read(chatProvider.notifier).sendMessage(text);
  }

  Widget _modeChip(ChatMode mode) {
    switch (mode) {
      case ChatMode.online:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text('Online', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        );
      case ChatMode.offline:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text('Offline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        );
      case ChatMode.unknown:
        return const SizedBox.shrink();
    }
  }

  Widget _assistantModeIcon(ChatMode mode) {
    if (mode == ChatMode.online) {
      return const Icon(Icons.cloud_outlined, size: 14, color: Colors.lightBlueAccent);
    }
    if (mode == ChatMode.offline) {
      return const Icon(Icons.phone_android, size: 14, color: Colors.orange);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DataGym AI'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _modeChip(state.currentMode)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.messages.length,
              itemBuilder: (context, index) {
                final msg = state.messages[index];
                final isUser = msg.isUser;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? colors.primary : Colors.white12,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isUser) ...[
                          _assistantModeIcon(msg.mode),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(msg.text, style: const TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(hintText: 'Pregunta sobre tu progreso...'),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: state.isLoading ? null : _sendMessage,
                  style: FilledButton.styleFrom(minimumSize: const Size(56, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}
