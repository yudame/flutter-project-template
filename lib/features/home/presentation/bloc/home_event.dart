part of 'home_bloc.dart';

@immutable
sealed class HomeEvent {
  const HomeEvent();

  const factory HomeEvent.load() = HomeLoad;
  const factory HomeEvent.refresh() = HomeRefresh;
  const factory HomeEvent.createItem({
    required String title,
    String? description,
  }) = HomeCreateItem;
  const factory HomeEvent.updateItem(Item item) = HomeUpdateItem;
  const factory HomeEvent.deleteItem(String id) = HomeDeleteItem;
  const factory HomeEvent.processQueue() = HomeProcessQueue;
}

final class HomeLoad extends HomeEvent {
  const HomeLoad();

  @override
  bool operator ==(Object other) => identical(this, other) || other is HomeLoad;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'HomeEvent.load()';
}

final class HomeRefresh extends HomeEvent {
  const HomeRefresh();

  @override
  bool operator ==(Object other) => identical(this, other) || other is HomeRefresh;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'HomeEvent.refresh()';
}

final class HomeCreateItem extends HomeEvent {
  final String title;
  final String? description;

  const HomeCreateItem({
    required this.title,
    this.description,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeCreateItem &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          description == other.description;

  @override
  int get hashCode => Object.hash(title, description);

  @override
  String toString() => 'HomeEvent.createItem(title: $title, description: $description)';
}

final class HomeUpdateItem extends HomeEvent {
  final Item item;

  const HomeUpdateItem(this.item);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeUpdateItem && runtimeType == other.runtimeType && item == other.item;

  @override
  int get hashCode => item.hashCode;

  @override
  String toString() => 'HomeEvent.updateItem($item)';
}

final class HomeDeleteItem extends HomeEvent {
  final String id;

  const HomeDeleteItem(this.id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeDeleteItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'HomeEvent.deleteItem($id)';
}

final class HomeProcessQueue extends HomeEvent {
  const HomeProcessQueue();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HomeProcessQueue;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'HomeEvent.processQueue()';
}
