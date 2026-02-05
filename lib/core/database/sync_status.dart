import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_status.freezed.dart';

/// Tracks the synchronization state of local data with remote.
///
/// Used to show sync indicators in the UI and manage
/// the offline queue processing.
///
/// Example usage in UI:
/// ```dart
/// syncStatus.when(
///   synced: () => const SizedBox.shrink(),
///   pending: () => const LinearProgressIndicator(),
///   syncing: () => const LinearProgressIndicator(),
///   error: (msg) => Text('Sync failed: $msg'),
/// );
/// ```
@freezed
class SyncStatus with _$SyncStatus {
  /// Document is in sync with remote.
  const factory SyncStatus.synced() = SyncStatusSynced;

  /// Document has local changes not yet pushed to remote.
  const factory SyncStatus.pending() = SyncStatusPending;

  /// Document failed to sync (will retry).
  const factory SyncStatus.error(String message) = SyncStatusError;

  /// Document is currently syncing.
  const factory SyncStatus.syncing() = SyncStatusSyncing;
}
