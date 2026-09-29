part of 'home_bloc.dart';

@immutable
sealed class HomeState {
  const HomeState();

  const factory HomeState.initial() = HomeInitial;
  const factory HomeState.loading() = HomeLoading;
  const factory HomeState.loaded(List<Item> items) = HomeLoaded;
  const factory HomeState.error(String message) = HomeError;

  R when<R>({
    required R Function() initial,
    required R Function() loading,
    required R Function(List<Item> items) loaded,
    required R Function(String message) error,
  }) =>
      switch (this) {
        HomeInitial() => initial(),
        HomeLoading() => loading(),
        HomeLoaded(:final items) => loaded(items),
        HomeError(:final message) => error(message),
      };

  R? whenOrNull<R>({
    R Function()? initial,
    R Function()? loading,
    R Function(List<Item> items)? loaded,
    R Function(String message)? error,
  }) =>
      switch (this) {
        HomeInitial() => initial?.call(),
        HomeLoading() => loading?.call(),
        HomeLoaded(:final items) => loaded?.call(items),
        HomeError(:final message) => error?.call(message),
      };
}

final class HomeInitial extends HomeState {
  const HomeInitial();

  @override
  bool operator ==(Object other) => identical(this, other) || other is HomeInitial;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'HomeState.initial()';
}

final class HomeLoading extends HomeState {
  const HomeLoading();

  @override
  bool operator ==(Object other) => identical(this, other) || other is HomeLoading;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'HomeState.loading()';
}

final class HomeLoaded extends HomeState {
  final List<Item> items;

  const HomeLoaded(this.items);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeLoaded &&
          runtimeType == other.runtimeType &&
          const ListEquality<Item>().equals(items, other.items);

  @override
  int get hashCode => const ListEquality<Item>().hash(items);

  @override
  String toString() => 'HomeState.loaded($items)';
}

final class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeError && runtimeType == other.runtimeType && message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'HomeState.error($message)';
}
