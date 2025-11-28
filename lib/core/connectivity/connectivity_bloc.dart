import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'connectivity_state.dart';

class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  final Connectivity _connectivity;
  final Dio _dio;
  Timer? _pingTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  static const _poorLatencyThreshold = Duration(milliseconds: 2000);
  static const _failureThreshold = 3;
  static const _pingInterval = Duration(seconds: 30);

  int _consecutiveFailures = 0;
  Duration? _lastLatency;

  ConnectivityBloc({
    required Connectivity connectivity,
    required Dio dio,
  })  : _connectivity = connectivity,
        _dio = dio,
        super(const ConnectivityState.offline()) {
    on<ConnectivityEvent>(_onEvent);
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        if (results.contains(ConnectivityResult.none) || results.isEmpty) {
          add(const ConnectivityEvent.disconnected());
        } else {
          add(const ConnectivityEvent.connected());
          _startLatencyMonitoring();
        }
      },
    );

    // Check initial state
    _connectivity.checkConnectivity().then((results) {
      if (results.contains(ConnectivityResult.none) || results.isEmpty) {
        add(const ConnectivityEvent.disconnected());
      } else {
        add(const ConnectivityEvent.connected());
        _startLatencyMonitoring();
      }
    });
  }

  Future<void> _onEvent(
    ConnectivityEvent event,
    Emitter<ConnectivityState> emit,
  ) async {
    await event.when(
      connected: () async => _onConnected(emit),
      disconnected: () async {
        _stopLatencyMonitoring();
        emit(const ConnectivityState.offline());
      },
      stable: () async => emit(const ConnectivityState.online()),
      degraded: () async => emit(const ConnectivityState.poor()),
    );
  }

  Future<void> _onConnected(Emitter<ConnectivityState> emit) async {
    // Optimistically assume online until proven otherwise
    emit(const ConnectivityState.online());
    await _checkLatency();
  }

  void _startLatencyMonitoring() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) => _checkLatency());
  }

  void _stopLatencyMonitoring() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> _checkLatency() async {
    final stopwatch = Stopwatch()..start();

    try {
      await _dio.head(
        '/health',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      stopwatch.stop();
      _lastLatency = stopwatch.elapsed;
      _consecutiveFailures = 0;

      if (_lastLatency! > _poorLatencyThreshold) {
        add(const ConnectivityEvent.degraded());
      } else {
        add(const ConnectivityEvent.stable());
      }
    } catch (e) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= _failureThreshold) {
        add(const ConnectivityEvent.degraded());
      }
    }
  }

  @override
  Future<void> close() {
    _pingTimer?.cancel();
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
