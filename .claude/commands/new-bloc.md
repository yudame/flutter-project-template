Create a new BLoC with Dart 3 sealed events and states.

## Input Required

Ask for:
- **BLoC name** (PascalCase, e.g., "Profile", "Settings", "Cart")
- **Associated model** (if any)
- **Custom events** (beyond standard CRUD)
- **Feature location**

## Files Created

Creates three files in `lib/features/{feature}/presentation/bloc/`:

### {name}_bloc.dart

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../../../../core/connectivity/connectivity_bloc.dart';
import '../../../../core/connectivity/connectivity_state.dart';
import '../../../../core/utils/connectivity_aware_mixin.dart';
import '../../../../core/utils/result.dart';
// Import repository and model as needed

part '{name}_event.dart';
part '{name}_state.dart';

class {Name}Bloc extends Bloc<{Name}Event, {Name}State>
    with ConnectivityAwareBlocMixin {
  // Add repository if needed
  // final {Name}Repository _repository;

  @override
  final ConnectivityBloc connectivityBloc;

  {Name}Bloc({
    // required {Name}Repository repository,
    required this.connectivityBloc,
  }) : // _repository = repository,
       super(const {Name}State.initial()) {
    initConnectivityListener();

    on<{Name}Event>((event, emit) async {
      switch (event) {
        case {Name}Load():
          await _onLoad(emit);
        case {Name}Refresh():
          await _onRefresh(emit);
        // Add other event handlers
      }
    });
  }

  @override
  void onConnectivityChanged(ConnectivityState state) {
    if (state is ConnectivityOnline) {
      add(const {Name}Event.load());
    }
  }

  Future<void> _onLoad(Emitter<{Name}State> emit) async {
    emit(const {Name}State.loading());

    // final result = await _repository.getItems();
    // switch (result) {
    //   case Success(:final data):
    //     emit({Name}State.loaded(data));
    //   case Failure(:final message):
    //     emit({Name}State.error(message));
    //   case Loading():
    //     break;
    // }

    emit(const {Name}State.loaded()); // Placeholder
  }

  Future<void> _onRefresh(Emitter<{Name}State> emit) async {
    // Implement refresh
  }
}
```

### {name}_event.dart

```dart
part of '{name}_bloc.dart';

@immutable
sealed class {Name}Event {
  const {Name}Event();

  const factory {Name}Event.load() = {Name}Load;
  const factory {Name}Event.refresh() = {Name}Refresh;
}

final class {Name}Load extends {Name}Event {
  const {Name}Load();

  @override
  bool operator ==(Object other) => identical(this, other) || other is {Name}Load;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class {Name}Refresh extends {Name}Event {
  const {Name}Refresh();

  @override
  bool operator ==(Object other) => identical(this, other) || other is {Name}Refresh;

  @override
  int get hashCode => runtimeType.hashCode;
}
```

### {name}_state.dart

```dart
part of '{name}_bloc.dart';

@immutable
sealed class {Name}State {
  const {Name}State();

  const factory {Name}State.initial() = {Name}Initial;
  const factory {Name}State.loading() = {Name}Loading;
  const factory {Name}State.loaded() = {Name}Loaded;
  const factory {Name}State.error(String message) = {Name}Error;
}

final class {Name}Initial extends {Name}State {
  const {Name}Initial();

  @override
  bool operator ==(Object other) => identical(this, other) || other is {Name}Initial;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class {Name}Loading extends {Name}State {
  const {Name}Loading();

  @override
  bool operator ==(Object other) => identical(this, other) || other is {Name}Loading;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class {Name}Loaded extends {Name}State {
  const {Name}Loaded();

  @override
  bool operator ==(Object other) => identical(this, other) || other is {Name}Loaded;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class {Name}Error extends {Name}State {
  final String message;
  const {Name}Error(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is {Name}Error && runtimeType == other.runtimeType && message == other.message;

  @override
  int get hashCode => message.hashCode;
}
```

## After Generation

1. Register in DI (`lib/core/di/injection.dart`) if needed:
   ```dart
   getIt.registerFactory<{Name}Bloc>(
     () => {Name}Bloc(
       // repository: getIt<{Name}Repository>(),
       connectivityBloc: getIt<ConnectivityBloc>(),
     ),
   );
   ```

2. Add `BlocProvider` in widget tree where needed:
   ```dart
   BlocProvider(
     create: (_) => getIt<{Name}Bloc>()..add(const {Name}Event.load()),
     child: const {Name}Page(),
   )
   ```

3. Create tests in `test/features/{feature}/presentation/bloc/{name}_bloc_test.dart`
