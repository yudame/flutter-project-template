import 'package:meta/meta.dart';

@immutable
sealed class ConnectivityState {
  const ConnectivityState();

  const factory ConnectivityState.online() = ConnectivityOnline;
  const factory ConnectivityState.poor() = ConnectivityPoor;
  const factory ConnectivityState.offline() = ConnectivityOffline;

  R when<R>({
    required R Function() online,
    required R Function() poor,
    required R Function() offline,
  }) =>
      switch (this) {
        ConnectivityOnline() => online(),
        ConnectivityPoor() => poor(),
        ConnectivityOffline() => offline(),
      };

  R? whenOrNull<R>({
    R Function()? online,
    R Function()? poor,
    R Function()? offline,
  }) =>
      switch (this) {
        ConnectivityOnline() => online?.call(),
        ConnectivityPoor() => poor?.call(),
        ConnectivityOffline() => offline?.call(),
      };

  R maybeWhen<R>({
    R Function()? online,
    R Function()? poor,
    R Function()? offline,
    required R Function() orElse,
  }) =>
      switch (this) {
        ConnectivityOnline() => online?.call() ?? orElse(),
        ConnectivityPoor() => poor?.call() ?? orElse(),
        ConnectivityOffline() => offline?.call() ?? orElse(),
      };
}

final class ConnectivityOnline extends ConnectivityState {
  const ConnectivityOnline();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConnectivityOnline;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ConnectivityState.online()';
}

final class ConnectivityPoor extends ConnectivityState {
  const ConnectivityPoor();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConnectivityPoor;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ConnectivityState.poor()';
}

final class ConnectivityOffline extends ConnectivityState {
  const ConnectivityOffline();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConnectivityOffline;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ConnectivityState.offline()';
}

@immutable
sealed class ConnectivityEvent {
  const ConnectivityEvent();

  const factory ConnectivityEvent.connected() = ConnectivityConnected;
  const factory ConnectivityEvent.disconnected() = ConnectivityDisconnected;
  const factory ConnectivityEvent.stable() = ConnectivityStable;
  const factory ConnectivityEvent.degraded() = ConnectivityDegraded;

  R when<R>({
    required R Function() connected,
    required R Function() disconnected,
    required R Function() stable,
    required R Function() degraded,
  }) =>
      switch (this) {
        ConnectivityConnected() => connected(),
        ConnectivityDisconnected() => disconnected(),
        ConnectivityStable() => stable(),
        ConnectivityDegraded() => degraded(),
      };
}

final class ConnectivityConnected extends ConnectivityEvent {
  const ConnectivityConnected();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConnectivityConnected;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ConnectivityEvent.connected()';
}

final class ConnectivityDisconnected extends ConnectivityEvent {
  const ConnectivityDisconnected();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConnectivityDisconnected;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ConnectivityEvent.disconnected()';
}

final class ConnectivityStable extends ConnectivityEvent {
  const ConnectivityStable();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConnectivityStable;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ConnectivityEvent.stable()';
}

final class ConnectivityDegraded extends ConnectivityEvent {
  const ConnectivityDegraded();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConnectivityDegraded;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ConnectivityEvent.degraded()';
}
