import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
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

  Future<Box<String>> _getBox() async {
    if (_hive.isBoxOpen(_boxName)) {
      return _hive.box<String>(_boxName);
    }
    return _hive.openBox<String>(_boxName);
  }

  Future<void> add(RequestType type, Map<String, dynamic> params) async {
    // Generate or extract idempotency key
    final idempotencyKey = params['idempotency_key'] as String? ??
        '${type.name}_${params.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
    params['idempotency_key'] = idempotencyKey;

    final box = await _getBox();

    // Check for existing request with same idempotency key
    final existing = box.values.any((jsonStr) {
      try {
        final r = QueuedRequest.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
        return r.type == type && r.params['idempotency_key'] == idempotencyKey;
      } catch (_) {
        return false;
      }
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
    final box = await _getBox();
    final requests = box.values
        .map((jsonStr) {
          try {
            return QueuedRequest.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<QueuedRequest>()
        .toList()
      ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

    if (requests.isEmpty) return;

    _logger.i('Processing ${requests.length} queued requests');

    for (final request in requests) {
      try {
        await _executor.execute(request);
        await box.delete(request.id);
        _logger.i('Processed ${request.type.name}: ${request.id}');
      } on AuthException {
        _logger.e('Auth failed, stopping queue processing');
        break;
      } catch (e, stack) {
        final shouldStopQueue = await _handleFailedRequest(request, box, e, stack);
        if (shouldStopQueue) {
          _logger.w('Stopping queue processing due to network error');
          break;
        }
      }
    }
  }

  /// Handles failure for a single queued request.
  /// Returns `true` if processing the remainder of the queue should be aborted (e.g. network down).
  Future<bool> _handleFailedRequest(
    QueuedRequest request,
    Box<String> box,
    dynamic error,
    StackTrace stack,
  ) async {
    // Check if error is a permanent client error (4xx except 408 timeout or 429 rate limit)
    final isPermanentClientError = error is DioException &&
        error.response?.statusCode != null &&
        error.response!.statusCode! >= 400 &&
        error.response!.statusCode! < 500 &&
        error.response!.statusCode! != 408 &&
        error.response!.statusCode! != 429;

    if (isPermanentClientError || request.retryCount >= _maxRetries) {
      _logger.e(
        'Dropping request ${request.id} (permanent error or max retries exceeded): $error',
      );
      await Sentry.captureException(
        error,
        stackTrace: stack,
        hint: Hint.withMap({'request_params': request.params}),
      );
      await box.delete(request.id);
      return false; // Not a general network outage, proceed with next item
    }

    // Transient failure: increment retry count
    final updated = request.copyWith(
      retryCount: request.retryCount + 1,
    );
    await box.put(request.id, jsonEncode(updated.toJson()));
    _logger.w('Request ${request.id} failed, retry count: ${updated.retryCount}');

    // If it's a network connection drop, pause queue processing for this cycle
    final isConnectionError = error is DioException &&
        (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout);
    return isConnectionError;
  }

  Duration getBackoffDelay(int retryCount) {
    final seconds = min(pow(2, retryCount).toInt(), 30);
    final jitter = Random().nextInt(1000);
    return Duration(seconds: seconds, milliseconds: jitter);
  }

  Future<int> get queueLength async {
    final box = await _getBox();
    return box.length;
  }

  Future<void> clearQueue() async {
    final box = await _getBox();
    await box.clear();
    _logger.i('Queue cleared');
  }
}
