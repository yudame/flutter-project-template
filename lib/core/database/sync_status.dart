import 'package:meta/meta.dart';

/// Tracks the synchronization state of local data with remote using Dart 3 sealed classes.
///
/// Used to show sync indicators in the UI and manage
/// the offline queue processing.
///
/// Example usage in UI:
/// ```dart
/// switch (syncStatus) {
///   SyncStatusSynced() => const SizedBox.shrink(),
///   SyncStatusPending() || SyncStatusSyncing() => const LinearProgressIndicator(),
///   SyncStatusError(:final message) => Text('Sync failed: $message'),
/// }
/// ```
@immutable
sealed class SyncStatus {
  const SyncStatus();

  /// Document is in sync with remote.
  const factory SyncStatus.synced() = SyncStatusSynced;

  /// Document has local changes not yet pushed to remote.
  const factory SyncStatus.pending() = SyncStatusPending;

  /// Document failed to sync (will retry).
  const factory SyncStatus.error(String message) = SyncStatusError;

  /// Document is currently syncing.
  const factory SyncStatus.syncing() = SyncStatusSyncing;

  R when<R>({
    required R Function() synced,
    required R Function() pending,
    required R Function(String message) error,
    required R Function() syncing,
  }) =>
      switch (this) {
        SyncStatusSynced() => synced(),
        SyncStatusPending() => pending(),
        SyncStatusError(:final message) => error(message),
        SyncStatusSyncing() => syncing(),
      };
}

final class SyncStatusSynced extends SyncStatus {
  const SyncStatusSynced();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SyncStatusSynced;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'SyncStatus.synced()';
}

final class SyncStatusPending extends SyncStatus {
  const SyncStatusPending();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SyncStatusPending;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'SyncStatus.pending()';
}

final class SyncStatusError extends SyncStatus {
  final String message;
  const SyncStatusError(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStatusError &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'SyncStatus.error($message)';
}

final class SyncStatusSyncing extends SyncStatus {
  const SyncStatusSyncing();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SyncStatusSyncing;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'SyncStatus.syncing()';
}
