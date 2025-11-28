import 'connectivity_bloc.dart';
import 'connectivity_state.dart';

abstract class ConnectivityService {
  Stream<ConnectivityState> get stream;
  ConnectivityState get currentState;
  bool get isOnline;
  bool get isPoor;
  bool get isOffline;
}

class ConnectivityServiceImpl implements ConnectivityService {
  final ConnectivityBloc _bloc;

  ConnectivityServiceImpl(this._bloc);

  @override
  Stream<ConnectivityState> get stream => _bloc.stream;

  @override
  ConnectivityState get currentState => _bloc.state;

  @override
  bool get isOnline => currentState is ConnectivityOnline;

  @override
  bool get isPoor => currentState is ConnectivityPoor;

  @override
  bool get isOffline => currentState is ConnectivityOffline;
}
