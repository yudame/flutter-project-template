import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_template/core/connectivity/connectivity_bloc.dart';
import 'package:flutter_template/core/connectivity/connectivity_state.dart';
import 'package:mocktail/mocktail.dart';

/// Sets up a mock ConnectivityBloc with configurable state
MockConnectivityBloc createMockConnectivityBloc({
  ConnectivityState initialState = const ConnectivityState.online(),
  Stream<ConnectivityState>? stream,
}) {
  final bloc = MockConnectivityBloc();
  when(() => bloc.state).thenReturn(initialState);
  when(() => bloc.stream).thenAnswer((_) => stream ?? const Stream.empty());
  return bloc;
}

/// Common test setup that should run in setUpAll
/// Add registerFallbackValue calls here for your models
void setupTestDependencies() {
  // Register fallback values for mocktail any() matchers
  // Example: registerFallbackValue(FakeItem());
}

/// Mock ConnectivityBloc for testing BLoCs that depend on connectivity
class MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}
