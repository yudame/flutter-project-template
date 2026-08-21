part of 'chat_bloc.dart';

@freezed
abstract class ChatState with _$ChatState {
  /// No message sent yet.
  const factory ChatState.initial() = ChatInitial;

  /// Establishing the stream / waiting for the first token.
  const factory ChatState.loading() = ChatLoading;

  /// Streaming in progress; [text] is the accumulated message so far.
  const factory ChatState.streaming(String text) = ChatStreaming;

  /// The stream reached `[DONE]` — [text] is the complete message.
  const factory ChatState.completed(String text) = ChatCompleted;

  /// The stream was aborted (user stop or max-length bound) — [text] is the
  /// partial message. Never treated as a successful completion.
  const factory ChatState.stopped(String text) = ChatStopped;

  /// The stream failed mid-flight.
  const factory ChatState.error(String message) = ChatError;
}
