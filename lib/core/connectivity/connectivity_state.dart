import 'package:freezed_annotation/freezed_annotation.dart';

part 'connectivity_state.freezed.dart';

@freezed
abstract class ConnectivityState with _$ConnectivityState {
  const factory ConnectivityState.online() = ConnectivityOnline;
  const factory ConnectivityState.poor() = ConnectivityPoor;
  const factory ConnectivityState.offline() = ConnectivityOffline;
}

@freezed
abstract class ConnectivityEvent with _$ConnectivityEvent {
  const factory ConnectivityEvent.connected() = _Connected;
  const factory ConnectivityEvent.disconnected() = _Disconnected;
  const factory ConnectivityEvent.stable() = _Stable;
  const factory ConnectivityEvent.degraded() = _Degraded;
}
