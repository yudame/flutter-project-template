import 'package:freezed_annotation/freezed_annotation.dart';

part 'result.freezed.dart';

/// A Result type for handling success/failure states in a type-safe way.
@freezed
class Result<T> with _$Result<T> {
  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(String message, [Object? error]) = Failure<T>;
  const factory Result.loading() = Loading<T>;
}

/// Extension methods for Result type
extension ResultExtension<T> on Result<T> {
  /// Returns the data if success, otherwise returns null
  T? get dataOrNull => whenOrNull(success: (data) => data);

  /// Returns the error message if failure, otherwise returns null
  String? get errorOrNull => whenOrNull(failure: (message, _) => message);

  /// Returns true if the result is a success
  bool get isSuccess => this is Success<T>;

  /// Returns true if the result is a failure
  bool get isFailure => this is Failure<T>;

  /// Returns true if the result is loading
  bool get isLoading => this is Loading<T>;

  /// Maps the success data to a new type
  Result<R> mapSuccess<R>(R Function(T data) mapper) {
    return when(
      success: (data) => Result.success(mapper(data)),
      failure: (message, error) => Result.failure(message, error),
      loading: () => const Result.loading(),
    );
  }

  /// Execute a callback based on the result type
  void execute({
    void Function(T data)? onSuccess,
    void Function(String message, Object? error)? onFailure,
    void Function()? onLoading,
  }) {
    when(
      success: (data) => onSuccess?.call(data),
      failure: (message, error) => onFailure?.call(message, error),
      loading: () => onLoading?.call(),
    );
  }
}
