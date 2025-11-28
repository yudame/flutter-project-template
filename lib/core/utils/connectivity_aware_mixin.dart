import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../connectivity/connectivity_bloc.dart';
import '../connectivity/connectivity_state.dart';

/// A mixin that provides connectivity awareness to BLoCs.
///
/// Usage:
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState>
///     with ConnectivityAwareBlocMixin {
///   @override
///   final ConnectivityBloc connectivityBloc;
///
///   MyBloc(this.connectivityBloc) : super(const MyState.initial()) {
///     initConnectivityListener();
///     on<MyEvent>(_onEvent);
///   }
///
///   @override
///   void onConnectivityChanged(ConnectivityState state) {
///     state.whenOrNull(
///       online: () => add(const MyEvent.refresh()),
///     );
///   }
/// }
/// ```
mixin ConnectivityAwareBlocMixin<Event, State> on Bloc<Event, State> {
  ConnectivityBloc get connectivityBloc;

  StreamSubscription<ConnectivityState>? _connectivitySubscription;

  /// Called when connectivity state changes.
  /// Override this to handle connectivity changes.
  void onConnectivityChanged(ConnectivityState state) {}

  /// Initialize the connectivity listener.
  /// Call this in the BLoC constructor after setting up event handlers.
  void initConnectivityListener() {
    _connectivitySubscription = connectivityBloc.stream.listen(
      onConnectivityChanged,
    );
  }

  /// Get the current connectivity state
  ConnectivityState get currentConnectivity => connectivityBloc.state;

  /// Check if currently online
  bool get isOnline => currentConnectivity is ConnectivityOnline;

  /// Check if connectivity is poor
  bool get isPoorConnectivity => currentConnectivity is ConnectivityPoor;

  /// Check if currently offline
  bool get isOffline => currentConnectivity is ConnectivityOffline;

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
