import 'package:flutter/material.dart';

/// Renders the accumulating assistant message as tokens stream in.
///
/// Shows a subtle progress indicator while [isStreaming] is true and renders
/// [text] incrementally, so text appears before the full response completes.
class ChatStreamView extends StatelessWidget {
  const ChatStreamView({
    required this.text,
    this.isStreaming = false,
    super.key,
  });

  /// The accumulated message text.
  final String text;

  /// Whether tokens are still streaming in.
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = text.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isStreaming)
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Streaming…',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                )
              else
                Text(
                  'Assistant',
                  style: theme.textTheme.labelLarge,
                ),
              const SizedBox(height: 12),
              Text(
                isEmptyHint ? 'Waiting for response…' : text,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get isEmptyHint => text.isEmpty && !isStreaming;
}
