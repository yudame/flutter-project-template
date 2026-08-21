import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_template/core/connectivity/connectivity_service.dart';
import 'package:flutter_template/core/network/dio_client.dart';
import 'package:flutter_template/core/network/sse_parser.dart';
import 'package:flutter_template/core/network/streaming_client.dart';
import 'package:flutter_template/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/auth_helpers.dart';

/// A fake Dio `HttpClientAdapter` that captures the outgoing [RequestOptions]
/// and replays a scripted SSE body (data chunks and/or an injected error).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(List<_StreamEvent> events) : _events = events;

  final List<_StreamEvent> _events;
  RequestOptions? lastRequestOptions;
  bool called = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    called = true;
    lastRequestOptions = options;
    return ResponseBody(
      _buildBodyStream(),
      200,
      headers: const {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  Stream<Uint8List> _buildBodyStream() async* {
    for (final event in _events) {
      if (event.delay != null) await Future<void>.delayed(event.delay!);
      if (event.error != null) throw event.error!;
      yield Uint8List.fromList(event.bytes);
    }
  }

  @override
  void close({bool force = false}) {}
}

class _StreamEvent {
  _StreamEvent.data(String text, {this.delay})
      : bytes = utf8.encode(text),
        error = null;
  _StreamEvent.throwError(this.error)
      : bytes = const [],
        delay = null;

  final List<int> bytes;
  final Duration? delay;
  final Error? error;
}

class MockConnectivityService extends Mock implements ConnectivityService {}

Logger get _logger => Logger(printer: SimplePrinter(colors: false));

StreamingClient _buildClient(
  _FakeAdapter adapter, {
  bool isOffline = false,
  bool isPoor = false,
}) {
  final authManager = MockAuthTokenManager();
  when(() => authManager.isTokenExpired()).thenAnswer((_) async => false);
  when(() => authManager.getAccessToken()).thenAnswer((_) async => null);

  final dio = Dio()..httpClientAdapter = adapter;
  final dioClient = DioClient(
    dio: dio,
    logger: _logger,
    authManager: authManager,
  );

  final connectivity = MockConnectivityService();
  when(() => connectivity.isOffline).thenReturn(isOffline);
  when(() => connectivity.isPoor).thenReturn(isPoor);
  when(() => connectivity.isOnline).thenReturn(!isOffline && !isPoor);

  return StreamingClient(
    dioClient: dioClient,
    connectivity: connectivity,
    logger: _logger,
  );
}

void main() {
  group('StreamingClient', () {
    test(
      'overrides the global receiveTimeout and Accept header (BLOCKER B-1)',
      () async {
        final adapter = _FakeAdapter([
          _StreamEvent.data('data: hello\n\ndata: [DONE]\n\n'),
        ]);
        final client = _buildClient(adapter);

        final tokens = await client
            .stream('/chat')
            .where((r) => r.isSuccess)
            .map((r) => r.dataOrNull)
            .toList();

        expect(tokens, ['hello']);

        final opts = adapter.lastRequestOptions!;
        // The two pieces of the BLOCKER fix must be on the actual request.
        expect(opts.responseType, ResponseType.stream);
        expect(opts.receiveTimeout, Duration.zero,
            reason: 'null would silently fall back to the base 30s in Dio 5.x');
        expect(opts.sendTimeout, Duration.zero);

        final acceptKey =
            opts.headers.keys.firstWhere((k) => k.toLowerCase() == 'accept');
        expect(opts.headers[acceptKey], 'text/event-stream');
      },
    );

    test(
        'a sparse stream with gaps between tokens does not throw a '
        'receiveTimeout error', () async {
      final adapter = _FakeAdapter([
        _StreamEvent.data('data: one\n\n',
            delay: const Duration(milliseconds: 30)),
        _StreamEvent.data('data: two\n\n',
            delay: const Duration(milliseconds: 30)),
        _StreamEvent.data('data: [DONE]\n\n'),
      ]);
      final client = _buildClient(adapter);

      final tokens = await client
          .stream('/chat')
          .where((r) => r.isSuccess)
          .map((r) => r.dataOrNull)
          .toList();

      expect(tokens, ['one', 'two']);
    });

    test(
        'reuses the injected DioClient (baseUrl applied, no fresh Dio) '
        '(C-3)', () async {
      final adapter = _FakeAdapter([
        _StreamEvent.data('data: hi\n\ndata: [DONE]\n\n'),
      ]);
      final client = _buildClient(adapter);

      await client.stream('/chat').toList();

      // The request was routed through the configured DioClient's Dio.
      expect(adapter.called, isTrue);
      final opts = adapter.lastRequestOptions!;
      expect(opts.uri.path, contains('/chat'));
      expect(opts.uri.scheme, 'https');
      expect(opts.uri.host, 'api.example.com',
          reason: 'baseUrl from DioClient must be preserved');
    });

    test(
        'emits loading first, then one success per token, [DONE] not a token '
        '(C-1)', () async {
      final adapter = _FakeAdapter([
        _StreamEvent.data('data: a\n\ndata: b\n\ndata: [DONE]\n\n'),
      ]);
      final client = _buildClient(adapter);

      final results = await client.stream('/chat').toList();

      expect(results.first.isLoading, isTrue);
      final tokens =
          results.where((r) => r.isSuccess).map((r) => r.dataOrNull).toList();
      expect(tokens, ['a', 'b']);
      // [DONE] is a distinct terminal marker, never emitted as a token.
      expect(
          results.any((r) => r.isSuccess && r.dataOrNull == kSseDoneSentinel),
          isFalse);
      // Stream ended normally after [DONE].
      expect(results.last.isSuccess, isTrue);
    });

    test('a mid-stream error becomes a terminal Result.failure (C-1)',
        () async {
      final adapter = _FakeAdapter([
        _StreamEvent.data('data: partial\n\n'),
        _StreamEvent.throwError(StateError('connection reset')),
      ]);
      final client = _buildClient(adapter);

      final results = await client.stream('/chat').toList();

      final tokens =
          results.where((r) => r.isSuccess).map((r) => r.dataOrNull).toList();
      expect(tokens, ['partial']);
      expect(results.last.isFailure, isTrue);
      expect(results.last.errorOrNull, contains('Streaming failed'));
      // The stream terminated — nothing is left hanging.
    });

    test('emits an immediate failure when offline and issues no request (C-4)',
        () async {
      final adapter = _FakeAdapter([
        _StreamEvent.data('data: x\n\n'),
      ]);
      final client = _buildClient(adapter, isOffline: true);

      final results = await client.stream('/chat').toList();

      expect(results, hasLength(1));
      expect(results.single.isFailure, isTrue);
      expect(adapter.called, isFalse,
          reason: 'no request may be enqueued or issued offline');
    });

    test('emits an immediate failure when connectivity is poor (C-4)',
        () async {
      final adapter = _FakeAdapter([
        _StreamEvent.data('data: x\n\n'),
      ]);
      final client = _buildClient(adapter, isPoor: true);

      final results = await client.stream('/chat').toList();

      expect(results.single.isFailure, isTrue);
      expect(adapter.called, isFalse);
    });
  });
}
