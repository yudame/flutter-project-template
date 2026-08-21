import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../connectivity/connectivity_service.dart';
import '../utils/result.dart';
import 'dio_client.dart';
import 'sse_parser.dart';

/// A thin streaming wrapper over the existing [DioClient].
///
/// Unlike the request/response path, [StreamingClient] emits a
/// `Stream<Result<String>>` of decoded tokens so AI/chat features can render
/// text as it arrives instead of waiting for a full response.
///
/// It deliberately reuses the injected [DioClient] (and its configured `Dio`)
/// rather than building a fresh one, so baseUrl, `AuthInterceptor`, and debug
/// logging are preserved. Only the per-request streaming options are overridden.
///
/// ## Emission contract
///
/// The returned stream is **always well-terminated** — it never leaves a
/// consumer hanging:
///
/// 1. `Result.loading()` is emitted exactly once as the leading item.
/// 2. One `Result.success(token)` is emitted per SSE `data:` payload.
/// 3. The `[DONE]` sentinel ends the stream normally and is **not** emitted as
///    a token.
/// 4. A mid-stream error / disconnect / cancellation is converted into a
///    terminal `Result.failure(message, err)` before the stream closes.
///
/// ## Connectivity
///
/// A token stream cannot be replayed by the Hive-backed `OfflineQueue`, so no
/// enqueueing or cached replay is attempted. When connectivity is offline or
/// poor, [stream] emits `Result.failure` immediately (no request is issued and
/// no stream is left orphaned).
class StreamingClient {
  StreamingClient({
    required DioClient dioClient,
    required ConnectivityService connectivity,
    required Logger logger,
  })  : _dioClient = dioClient,
        _connectivity = connectivity,
        _logger = logger;

  final DioClient _dioClient;
  final ConnectivityService _connectivity;
  final Logger _logger;

  /// Streams decoded tokens from an SSE endpoint at [path].
  ///
  /// The [path] is resolved against the configured `Dio` baseUrl. Pass
  /// [queryParameters] for request query strings and [cancelToken] to allow the
  /// consumer to abort the stream (e.g. a user "stop" action).
  Stream<Result<String>> stream(
    String path, {
    CancelToken? cancelToken,
    Map<String, dynamic>? queryParameters,
  }) async* {
    // Connectivity gate: streaming cannot be replayed from the offline queue,
    // so offline/poor is a terminal failure — nothing is enqueued.
    if (_connectivity.isOffline || _connectivity.isPoor) {
      yield const Result.failure(
        'No connection — streaming requires a stable connection',
      );
      return;
    }

    yield const Result.loading();

    // Per-request options override the global defaults (BLOCKER B-1).
    //
    // - `receiveTimeout: Duration.zero` disables Dio's receive-timeout timer so
    //   a sparse, long-lived stream (tokens >30s apart) is not aborted.
    //   (`null` would silently fall back to the base 30s in Dio 5.x.)
    // - `Accept: text/event-stream` prevents the backend from buffering the
    //   full body and overrides the template's default `Accept: application/json`.
    final options = Options(
      responseType: ResponseType.stream,
      receiveTimeout: Duration.zero,
      sendTimeout: Duration.zero,
      headers: const {'Accept': 'text/event-stream'},
    );

    try {
      final response = await _dioClient.get<ResponseBody>(
        path,
        options: options,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );

      final body = response.data;
      if (body == null) {
        yield const Result.failure('Empty streaming response');
        return;
      }

      await for (final event in parseSseBytes(body.stream)) {
        if (event.isDone) {
          // `[DONE]` — normal terminal; not emitted as a token.
          return;
        }
        if (event.isError) {
          yield Result.failure(event.data);
          return;
        }
        yield Result.success(event.data);
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        yield Result.failure('Stream cancelled', e);
        return;
      }
      _logger.e('Streaming request failed for $path: ${e.message}');
      yield Result.failure('Streaming failed: ${e.message}', e);
    } catch (e) {
      _logger.e('Streaming request failed for $path: $e');
      yield Result.failure('Streaming failed: $e', e);
    }
  }
}
