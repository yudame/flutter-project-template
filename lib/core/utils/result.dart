import 'package:meta/meta.dart';

/// A Result type for handling success/failure states in a type-safe way using Dart 3 sealed classes.
@immutable
sealed class Result<T> {
  const Result();

  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(String message, [Object? error, StackTrace? stackTrace]) =
      Failure<T>;
  const factory Result.loading() = Loading<T>;

  /// Returns the data if success, otherwise returns null
  T? get dataOrNull => switch (this) {
        Success(:final data) => data,
        _ => null,
      };

  /// Returns the error message if failure, otherwise returns null
  String? get errorOrNull => switch (this) {
        Failure(:final message) => message,
        _ => null,
      };

  /// Returns true if the result is a success
  bool get isSuccess => this is Success<T>;

  /// Returns true if the result is a failure
  bool get isFailure => this is Failure<T>;

  /// Returns true if the result is loading
  bool get isLoading => this is Loading<T>;

  /// Pattern matching helper for backwards compatibility and functional handling
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, Object? error) failure,
    required R Function() loading,
  }) =>
      switch (this) {
        Success(:final data) => success(data),
        Failure(:final message, :final error) => failure(message, error),
        Loading() => loading(),
      };

  /// Pattern matching helper with fallback
  R? whenOrNull<R>({
    R Function(T data)? success,
    R Function(String message, Object? error)? failure,
    R Function()? loading,
  }) =>
      switch (this) {
        Success(:final data) => success?.call(data),
        Failure(:final message, :final error) => failure?.call(message, error),
        Loading() => loading?.call(),
      };

  /// Maps the success data to a new type
  Result<R> mapSuccess<R>(R Function(T data) mapper) => switch (this) {
        Success(:final data) => Result.success(mapper(data)),
        Failure(:final message, :final error, :final stackTrace) =>
          Failure<R>(message, error, stackTrace),
        Loading() => const Result.loading(),
      };

  /// Execute a callback based on the result type
  void execute({
    void Function(T data)? onSuccess,
    void Function(String message, Object? error)? onFailure,
    void Function()? onLoading,
  }) {
    switch (this) {
      case Success(:final data):
        onSuccess?.call(data);
      case Failure(:final message, :final error):
        onFailure?.call(message, error);
      case Loading():
        onLoading?.call();
    }
  }
}

/// Represents a successful result with data.
final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> && runtimeType == other.runtimeType && data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Result.success($data)';
}

/// Represents a failed result with an error message.
final class Failure<T> extends Result<T> {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  const Failure(this.message, [this.error, this.stackTrace]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          error == other.error;

  @override
  int get hashCode => Object.hash(message, error);

  @override
  String toString() => 'Result.failure($message, error: $error)';
}

/// Represents an in-flight operation.
final class Loading<T> extends Result<T> {
  const Loading();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Loading<T> && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'Result.loading()';
}
