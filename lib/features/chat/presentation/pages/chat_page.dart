import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../shared/widgets/connectivity_banner.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../bloc/chat_bloc.dart';
import '../widgets/chat_stream_view.dart';

/// Reference streaming-chat page.
///
/// Renders assistant tokens incrementally via [ChatStreamView] and exposes a
/// send / stop pair wired to [ChatBloc].
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ChatBloc>(),
      child: const ChatView(),
    );
  }
}

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    _controller.clear();
    context.read<ChatBloc>().add(ChatEvent.send(message));
  }

  void _stop() {
    context.read<ChatBloc>().add(const ChatEvent.stop());
  }

  @override
  Widget build(BuildContext context) {
    return ConnectivityBanner(
      child: Scaffold(
        appBar: AppBar(title: const Text('Streaming Chat')),
        body: Column(
          children: [
            Expanded(
              child: BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  return state.when(
                    initial: () => const EmptyState(
                      title: 'Send a message',
                      subtitle:
                          'Assistant tokens will appear as they stream in',
                      icon: Icons.chat_bubble_outline,
                    ),
                    loading: () => const Center(
                      child: LoadingIndicator(message: 'Connecting…'),
                    ),
                    streaming: (text) =>
                        ChatStreamView(text: text, isStreaming: true),
                    completed: (text) => ChatStreamView(text: text),
                    stopped: (text) => ChatStreamView(
                      text: text.isEmpty ? 'Stopped' : '$text (stopped)',
                    ),
                    error: (message) => ErrorView(
                      message: message,
                      onRetry: _send,
                    ),
                  );
                },
              ),
            ),
            _Composer(
              controller: _controller,
              onSend: _send,
              onStop: _stop,
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final isStreaming = context.select(
      (ChatBloc bloc) =>
          bloc.state is ChatStreaming || bloc.state is ChatLoading,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => isStreaming ? onStop() : onSend(),
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Ask the assistant…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: isStreaming ? 'Stop' : 'Send',
              icon: Icon(isStreaming ? Icons.stop : Icons.send),
              onPressed: isStreaming ? onStop : onSend,
            ),
          ],
        ),
      ),
    );
  }
}
