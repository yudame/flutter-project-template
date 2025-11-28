import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/connectivity/connectivity_bloc.dart';
import '../../../../core/connectivity/connectivity_state.dart';
import '../../../../core/utils/connectivity_aware_mixin.dart';
import '../../../../core/utils/result.dart';
import '../../data/models/item.dart';
import '../../data/repositories/item_repository.dart';

part 'home_event.dart';
part 'home_state.dart';
part 'home_bloc.freezed.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState>
    with ConnectivityAwareBlocMixin {
  final ItemRepository _repository;

  @override
  final ConnectivityBloc connectivityBloc;

  HomeBloc({
    required ItemRepository repository,
    required this.connectivityBloc,
  })  : _repository = repository,
        super(const HomeState.initial()) {
    initConnectivityListener();

    on<HomeEvent>((event, emit) async {
      await event.when(
        load: () => _onLoad(emit),
        refresh: () => _onRefresh(emit),
        createItem: (title, description) =>
            _onCreateItem(title, description, emit),
        updateItem: (item) => _onUpdateItem(item, emit),
        deleteItem: (id) => _onDeleteItem(id, emit),
        processQueue: () => _onProcessQueue(emit),
      );
    });
  }

  @override
  void onConnectivityChanged(ConnectivityState state) {
    if (state is ConnectivityOnline) {
      add(const HomeEvent.processQueue());
      add(const HomeEvent.refresh());
    }
  }

  Future<void> _onLoad(Emitter<HomeState> emit) async {
    emit(const HomeState.loading());

    final result = await _repository.getItems();

    result.when(
      success: (items) => emit(HomeState.loaded(items)),
      failure: (message, _) => emit(HomeState.error(message)),
      loading: () => emit(const HomeState.loading()),
    );
  }

  Future<void> _onRefresh(Emitter<HomeState> emit) async {
    // Keep showing current items while refreshing
    final currentItems = state.whenOrNull(loaded: (items) => items);

    final result = await _repository.getItems();

    result.when(
      success: (items) => emit(HomeState.loaded(items)),
      failure: (message, _) {
        // If we have cached items, keep showing them
        if (currentItems != null && currentItems.isNotEmpty) {
          emit(HomeState.loaded(currentItems));
        } else {
          emit(HomeState.error(message));
        }
      },
      loading: () {},
    );
  }

  Future<void> _onCreateItem(
    String title,
    String? description,
    Emitter<HomeState> emit,
  ) async {
    final result = await _repository.createItem(
      title: title,
      description: description,
    );

    result.when(
      success: (item) {
        final currentItems =
            state.whenOrNull(loaded: (items) => items) ?? <Item>[];
        emit(HomeState.loaded([...currentItems, item]));
      },
      failure: (message, _) {
        // Item was queued, optimistically add it
        final currentItems =
            state.whenOrNull(loaded: (items) => items) ?? <Item>[];
        final optimisticItem = Item(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          description: description,
          createdAt: DateTime.now(),
        );
        emit(HomeState.loaded([...currentItems, optimisticItem]));
      },
      loading: () {},
    );
  }

  Future<void> _onUpdateItem(Item item, Emitter<HomeState> emit) async {
    // Optimistically update
    final currentItems = state.whenOrNull(loaded: (items) => items) ?? <Item>[];
    final updatedItems = currentItems.map((i) {
      return i.id == item.id ? item : i;
    }).toList();
    emit(HomeState.loaded(updatedItems));

    await _repository.updateItem(item);
  }

  Future<void> _onDeleteItem(String id, Emitter<HomeState> emit) async {
    // Optimistically delete
    final currentItems = state.whenOrNull(loaded: (items) => items) ?? <Item>[];
    final updatedItems = currentItems.where((i) => i.id != id).toList();
    emit(HomeState.loaded(updatedItems));

    await _repository.deleteItem(id);
  }

  Future<void> _onProcessQueue(Emitter<HomeState> emit) async {
    await _repository.processOfflineQueue();
  }
}
