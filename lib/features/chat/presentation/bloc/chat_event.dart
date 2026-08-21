part of 'chat_bloc.dart';

@freezed
abstract class ChatEvent with _$ChatEvent {
  /// Send a user message and begin streaming the assistant's response.
  const factory ChatEvent.send(String message) = _Send;

  /// Abort the in-flight stream (wires to the `CancelToken`).
  const factory ChatEvent.stop() = _Stop;
}
