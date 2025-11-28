part of 'home_bloc.dart';

@freezed
class HomeEvent with _$HomeEvent {
  const factory HomeEvent.load() = _Load;
  const factory HomeEvent.refresh() = _Refresh;
  const factory HomeEvent.createItem({
    required String title,
    String? description,
  }) = _CreateItem;
  const factory HomeEvent.updateItem(Item item) = _UpdateItem;
  const factory HomeEvent.deleteItem(String id) = _DeleteItem;
  const factory HomeEvent.processQueue() = _ProcessQueue;
}
