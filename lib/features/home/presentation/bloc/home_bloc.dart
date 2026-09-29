import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../../../../core/connectivity/connectivity_bloc.dart';
import '../../../../core/connectivity/connectivity_state.dart';
import '../../../../core/utils/connectivity_aware_mixin.dart';
import '../../../../core/utils/result.dart';
import '../../data/models/item.dart';
import '../../data/repositories/item_repository.dart';

part 'home_event.dart';
part 'home_state.dart';

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
      switch (event) {
        case HomeLoad():
          await _onLoad(emit);
        case HomeRefresh():
          await _onRefresh(emit);
        case HomeCreateItem(:final title, :final description):
          await _onCreateItem(title, description, emit);
        case HomeUpdateItem(:final item):
          await _onUpdateItem(item, emit);
        case HomeDeleteItem(:final id):
          await _onDeleteItem(id, emit);
        case HomeProcessQueue():
          await _onProcessQueue(emit);
      }
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

    switch (result) {
      case Success(:final data):
        emit(HomeState.loaded(data));
      case Failure(:final message):
        emit(HomeState.error(message));
      case Loading():
        emit(const HomeState.loading());
    }
  }

  Future<void> _onRefresh(Emitter<HomeState> emit) async {
    final currentItems = switch (state) {
      HomeLoaded(:final items) => items,
      _ => null,
    };

    final result = await _repository.getItems();

    switch (result) {
      case Success(:final data):
        emit(HomeState.loaded(data));
      case Failure(:final message):
        if (currentItems != null && currentItems.isNotEmpty) {
          emit(HomeState.loaded(currentItems));
        } else {
          emit(HomeState.error(message));
        }
      case Loading():
        break;
    }
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

    final currentItems = switch (state) {
      HomeLoaded(:final items) => items,
      _ => <Item>[],
    };

    switch (result) {
      case Success(:final data):
        emit(HomeState.loaded([...currentItems, data]));
      case Failure():
        final optimisticItem = Item(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          description: description,
          createdAt: DateTime.now(),
        );
        emit(HomeState.loaded([...currentItems, optimisticItem]));
      case Loading():
        break;
    }
  }

  Future<void> _onUpdateItem(Item item, Emitter<HomeState> emit) async {
    final currentItems = switch (state) {
      HomeLoaded(:final items) => items,
      _ => <Item>[],
    };
    final updatedItems =
        currentItems.map((i) => i.id == item.id ? item : i).toList();
    emit(HomeState.loaded(updatedItems));

    await _repository.updateItem(item);
  }

  Future<void> _onDeleteItem(String id, Emitter<HomeState> emit) async {
    final currentItems = switch (state) {
      HomeLoaded(:final items) => items,
      _ => <Item>[],
    };
    final updatedItems = currentItems.where((i) => i.id != id).toList();
    emit(HomeState.loaded(updatedItems));

    await _repository.deleteItem(id);
  }

  Future<void> _onProcessQueue(Emitter<HomeState> emit) async {
    await _repository.processOfflineQueue();
  }
}
