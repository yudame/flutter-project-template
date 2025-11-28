import 'dart:convert';
import 'dart:math';

import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';

import 'auth_exception.dart';
import 'queued_request.dart';
import 'request_executor.dart';

class QueueFullException implements Exception {
  final String message;
  const QueueFullException([this.message = 'Offline queue is full']);

  @override
  String toString() => 'QueueFullException: $message';
}

class OfflineQueue {
  final HiveInterface _hive;
  final RequestExecutor _executor;
  final Logger _logger;

  static const _boxName = 'offline_queue';
  static const _maxQueueSize = 100;
  static const _maxRetries = 3;

  OfflineQueue({
    required HiveInterface hive,
    required RequestExecutor executor,
    required Logger logger,
  })  : _hive = hive,
        _executor = executor,
        _logger = logger;

  Future<void> add(RequestType type, Map<String, dynamic> params) async {
    // Generate or extract idempotency key
    final idempotencyKey = params['idempotency_key'] as String? ??
        '${type.name}_${params.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
    params['idempotency_key'] = idempotencyKey;

    final box = await _hive.openBox<String>(_boxName);

    // Check for existing request with same idempotency key
    final existing = box.values.any((jsonStr) {
      final r = QueuedRequest.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      return r.type == type && r.params['idempotency_key'] == idempotencyKey;
    });

    if (existing) {
      _logger.i('Duplicate request ignored: $idempotencyKey');
      return;
    }

    // Check queue size
    if (box.length >= _maxQueueSize) {
      _logger.w('Queue full, cannot add request');
      throw const QueueFullException();
    }

    final request = QueuedRequest(
      id: const Uuid().v4(),
      type: type,
      params: params,
      queuedAt: DateTime.now(),
    );

    await box.put(request.id, jsonEncode(request.toJson()));
    _logger.i('Queued ${type.name} request: ${request.id}');
  }

  Future<void> processQueue() async {
    final box = await _hive.openBox<String>(_boxName);
    final requests = box.values
        .map((jsonStr) => QueuedRequest.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

    _logger.i('Processing ${requests.length} queued requests');

    for (final request in requests) {
      try {
        await _executeWithRetry(request);
        await box.delete(request.id);
        _logger.i('Processed ${request.type.name}: ${request.id}');
      } on AuthException {
        _logger.e('Auth failed, stopping queue processing');
        break;
      } catch (e, stack) {
        await _handleFailedRequest(request, box, e, stack);
      }
    }
  }

  Future<void> _executeWithRetry(QueuedRequest request) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        await _executor.execute(request);
        return;
      } catch (e) {
        if (attempt == _maxRetries) rethrow;

        final backoff = _getBackoffDelay(attempt);
        _logger.d('Retry attempt ${attempt + 1} after ${backoff.inSeconds}s');
        await Future.delayed(backoff);
      }
    }
  }

  Duration _getBackoffDelay(int retryCount) {
    // Exponential: 1s, 2s, 4s, 8s, max 30s
    final seconds = min(pow(2, retryCount).toInt(), 30);
    // Add jitter to avoid thundering herd
    final jitter = Random().nextInt(1000);
    return Duration(seconds: seconds, milliseconds: jitter);
  }

  Future<void> _handleFailedRequest(
    QueuedRequest request,
    Box<String> box,
    dynamic error,
    StackTrace stack,
  ) async {
    if (request.retryCount >= _maxRetries) {
      _logger.e('Max retries exceeded for ${request.id}, removing from queue');
      await Sentry.captureException(
        error,
        stackTrace: stack,
        hint: Hint.withMap({'request_params': request.params}),
      );
      await box.delete(request.id);
    } else {
      final updated = request.copyWith(
        retryCount: request.retryCount + 1,
      );
      await box.put(request.id, jsonEncode(updated.toJson()));
      _logger.w(
        'Request ${request.id} failed, retry count: ${updated.retryCount}',
      );
    }
  }

  Future<int> get queueLength async {
    final box = await _hive.openBox<String>(_boxName);
    return box.length;
  }

  Future<void> clearQueue() async {
    final box = await _hive.openBox<String>(_boxName);
    await box.clear();
    _logger.i('Queue cleared');
  }
}
