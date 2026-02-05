Create a new BLoC with Freezed events and states.

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
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/connectivity/connectivity_bloc.dart';
import '../../../../core/connectivity/connectivity_state.dart';
import '../../../../core/utils/connectivity_aware_mixin.dart';
import '../../../../core/utils/result.dart';
// Import repository and model as needed

part '{name}_event.dart';
part '{name}_state.dart';
part '{name}_bloc.freezed.dart';

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
      await event.when(
        load: () => _onLoad(emit),
        // Add other event handlers
      );
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

    // TODO: Implement data loading
    // final result = await _repository.getItems();
    // result.when(
    //   success: (data) => emit({Name}State.loaded(data)),
    //   failure: (message, _) => emit({Name}State.error(message)),
    //   loading: () {},
    // );

    emit(const {Name}State.loaded()); // Placeholder
  }
}
```

### {name}_event.dart

```dart
part of '{name}_bloc.dart';

@freezed
class {Name}Event with _${Name}Event {
  const factory {Name}Event.load() = _Load;
  const factory {Name}Event.refresh() = _Refresh;
  // Add custom events as specified
}
```

### {name}_state.dart

```dart
part of '{name}_bloc.dart';

@freezed
class {Name}State with _${Name}State {
  const factory {Name}State.initial() = _Initial;
  const factory {Name}State.loading() = _Loading;
  const factory {Name}State.loaded(/* Add data parameter if needed */) = _Loaded;
  const factory {Name}State.error(String message) = _Error;
}
```

## Common Event Patterns

For CRUD operations:
```dart
const factory {Name}Event.load() = _Load;
const factory {Name}Event.refresh() = _Refresh;
const factory {Name}Event.create{Item}({required String title}) = _Create{Item};
const factory {Name}Event.update{Item}({required {Item} item}) = _Update{Item};
const factory {Name}Event.delete{Item}(String id) = _Delete{Item};
```

For form handling:
```dart
const factory {Name}Event.fieldChanged({required String field, required String value}) = _FieldChanged;
const factory {Name}Event.submit() = _Submit;
const factory {Name}Event.reset() = _Reset;
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

2. Run code generation:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. Add `BlocProvider` in widget tree where needed:
   ```dart
   BlocProvider(
     create: (_) => getIt<{Name}Bloc>()..add(const {Name}Event.load()),
     child: const {Name}Page(),
   )
   ```

4. Create tests in `test/features/{feature}/presentation/bloc/{name}_bloc_test.dart`
