import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../../../core/network/streaming_client.dart';
import '../../../../core/utils/result.dart';

/// Repository for the reference streaming-chat feature.
///
/// Mirrors `features/home`'s repository pattern: the feature talks to a
/// repository, never to the network core directly. This one simply forwards
/// onto [StreamingClient] and exposes a `Stream<Result<String>>` of tokens.
class ChatRepository {
  ChatRepository({
    required StreamingClient streamingClient,
    required Logger logger,
  })  : _streamingClient = streamingClient,
        _logger = logger;

  final StreamingClient _streamingClient;
  final Logger _logger;

  /// The chat endpoint resolved against the configured `Dio` baseUrl.
  static const chatPath = '/chat';

  /// Streams assistant tokens for the user's [message].
  ///
  /// Pass [cancelToken] to allow the caller to abort the stream (e.g. a user
  /// "stop" action).
  Stream<Result<String>> stream(
    String message, {
    CancelToken? cancelToken,
  }) {
    _logger.i('Streaming chat request: $message');
    return _streamingClient.stream(
      chatPath,
      queryParameters: {'q': message},
      cancelToken: cancelToken,
    );
  }
}
