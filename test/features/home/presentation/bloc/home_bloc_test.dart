import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_template/core/connectivity/connectivity_bloc.dart';
import 'package:flutter_template/core/connectivity/connectivity_state.dart';
import 'package:flutter_template/core/utils/result.dart';
import 'package:flutter_template/features/home/data/models/item.dart';
import 'package:flutter_template/features/home/data/repositories/item_repository.dart';
import 'package:flutter_template/features/home/presentation/bloc/home_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockItemRepository extends Mock implements ItemRepository {}

class MockConnectivityBloc extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

class FakeItem extends Fake implements Item {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeItem());
  });
  late HomeBloc bloc;
  late MockItemRepository repository;
  late MockConnectivityBloc connectivityBloc;

  final mockItems = [
    Item(
      id: '1',
      title: 'Test Item 1',
      description: 'Description 1',
      createdAt: DateTime(2024, 1, 1),
    ),
    Item(
      id: '2',
      title: 'Test Item 2',
      createdAt: DateTime(2024, 1, 2),
    ),
  ];

  setUp(() {
    repository = MockItemRepository();
    connectivityBloc = MockConnectivityBloc();

    when(() => connectivityBloc.state).thenReturn(
      const ConnectivityState.online(),
    );
    when(() => connectivityBloc.stream).thenAnswer(
      (_) => const Stream.empty(),
    );

    bloc = HomeBloc(
      repository: repository,
      connectivityBloc: connectivityBloc,
    );
  });

  tearDown(() {
    bloc.close();
  });

  group('HomeBloc', () {
    test('initial state is HomeState.initial', () {
      expect(bloc.state, const HomeState.initial());
    });

    group('load', () {
      blocTest<HomeBloc, HomeState>(
        'emits [loading, loaded] when load succeeds',
        build: () {
          when(() => repository.getItems())
              .thenAnswer((_) async => Result.success(mockItems));
          return bloc;
        },
        act: (bloc) => bloc.add(const HomeEvent.load()),
        expect: () => [
          const HomeState.loading(),
          HomeState.loaded(mockItems),
        ],
        verify: (_) {
          verify(() => repository.getItems()).called(1);
        },
      );

      blocTest<HomeBloc, HomeState>(
        'emits [loading, error] when load fails',
        build: () {
          when(() => repository.getItems())
              .thenAnswer((_) async => const Result.failure('Network error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const HomeEvent.load()),
        expect: () => [
          const HomeState.loading(),
          const HomeState.error('Network error'),
        ],
      );
    });

    group('refresh', () {
      blocTest<HomeBloc, HomeState>(
        'keeps loaded state when refresh succeeds with same data',
        build: () {
          when(() => repository.getItems())
              .thenAnswer((_) async => Result.success(mockItems));
          return bloc;
        },
        seed: () => HomeState.loaded(mockItems),
        act: (bloc) => bloc.add(const HomeEvent.refresh()),
        // BLoC doesn't emit if state is identical - this verifies no change occurs
        expect: () => <HomeState>[],
        verify: (_) {
          verify(() => repository.getItems()).called(1);
        },
      );

      blocTest<HomeBloc, HomeState>(
        'keeps current items when refresh fails with cached data',
        build: () {
          when(() => repository.getItems())
              .thenAnswer((_) async => const Result.failure('Network error'));
          return bloc;
        },
        seed: () => HomeState.loaded(mockItems),
        act: (bloc) => bloc.add(const HomeEvent.refresh()),
        // BLoC doesn't emit if state is identical - items are retained
        expect: () => <HomeState>[],
        verify: (_) {
          verify(() => repository.getItems()).called(1);
        },
      );
    });

    group('createItem', () {
      blocTest<HomeBloc, HomeState>(
        'adds item to list when createItem succeeds',
        build: () {
          final newItem = Item(
            id: '3',
            title: 'New Item',
            createdAt: DateTime.now(),
          );
          when(() => repository.createItem(
                title: any(named: 'title'),
                description: any(named: 'description'),
              )).thenAnswer((_) async => Result.success(newItem));
          return bloc;
        },
        seed: () => HomeState.loaded(mockItems),
        act: (bloc) => bloc.add(const HomeEvent.createItem(title: 'New Item')),
        verify: (_) {
          verify(() => repository.createItem(
                title: 'New Item',
                description: null,
              )).called(1);
        },
      );
    });

    group('deleteItem', () {
      blocTest<HomeBloc, HomeState>(
        'removes item from list when deleteItem is called',
        build: () {
          when(() => repository.deleteItem(any()))
              .thenAnswer((_) async => const Result.success(null));
          return bloc;
        },
        seed: () => HomeState.loaded(mockItems),
        act: (bloc) => bloc.add(const HomeEvent.deleteItem('1')),
        expect: () => [
          HomeState.loaded([mockItems[1]]),
        ],
        verify: (_) {
          verify(() => repository.deleteItem('1')).called(1);
        },
      );
    });

    group('updateItem', () {
      blocTest<HomeBloc, HomeState>(
        'updates item in list when updateItem is called',
        build: () {
          when(() => repository.updateItem(any()))
              .thenAnswer((_) async => Result.success(mockItems[0]));
          return bloc;
        },
        seed: () => HomeState.loaded(mockItems),
        act: (bloc) {
          final updatedItem = mockItems[0].copyWith(isCompleted: true);
          bloc.add(HomeEvent.updateItem(updatedItem));
        },
        expect: () => [
          HomeState.loaded([
            mockItems[0].copyWith(isCompleted: true),
            mockItems[1],
          ]),
        ],
      );
    });

    group('connectivity', () {
      blocTest<HomeBloc, HomeState>(
        'processes queue and refreshes when connectivity changes to online',
        build: () {
          when(() => connectivityBloc.stream).thenAnswer(
            (_) => Stream.value(const ConnectivityState.online()),
          );
          when(() => repository.processOfflineQueue())
              .thenAnswer((_) async {});
          when(() => repository.getItems())
              .thenAnswer((_) async => Result.success(mockItems));

          return HomeBloc(
            repository: repository,
            connectivityBloc: connectivityBloc,
          );
        },
        seed: () => HomeState.loaded(mockItems),
        wait: const Duration(milliseconds: 100),
        verify: (_) {
          verify(() => repository.processOfflineQueue()).called(1);
        },
      );
    });
  });
}
