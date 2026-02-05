import 'sync_status.dart';

/// A document paired with its sync status and cache metadata.
///
/// Wraps raw data with tracking information for the offline-first pattern.
/// Used by repositories to track whether cached documents need syncing.
///
/// Example:
/// ```dart
/// final doc = CachedDocument(
///   id: 'item_123',
///   data: item.toJson(),
///   cachedAt: DateTime.now(),
/// );
///
/// // After successful sync:
/// final synced = doc.copyWith(
///   syncStatus: const SyncStatus.synced(),
///   syncedAt: DateTime.now(),
/// );
/// ```
class CachedDocument {
  /// The document ID.
  final String id;

  /// The raw document data as a JSON map.
  final Map<String, dynamic> data;

  /// Current sync status of this document.
  final SyncStatus syncStatus;

  /// When this document was cached locally.
  final DateTime cachedAt;

  /// When this document was last successfully synced with remote.
  /// Null if never synced.
  final DateTime? syncedAt;

  const CachedDocument({
    required this.id,
    required this.data,
    this.syncStatus = const SyncStatus.synced(),
    required this.cachedAt,
    this.syncedAt,
  });

  /// Create a copy with updated fields.
  CachedDocument copyWith({
    String? id,
    Map<String, dynamic>? data,
    SyncStatus? syncStatus,
    DateTime? cachedAt,
    DateTime? syncedAt,
  }) {
    return CachedDocument(
      id: id ?? this.id,
      data: data ?? this.data,
      syncStatus: syncStatus ?? this.syncStatus,
      cachedAt: cachedAt ?? this.cachedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  /// Whether this document has unsynced local changes.
  bool get needsSync => syncStatus is! SyncStatusSynced;

  @override
  String toString() =>
      'CachedDocument(id: $id, syncStatus: $syncStatus, cachedAt: $cachedAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedDocument &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          syncStatus == other.syncStatus &&
          cachedAt == other.cachedAt;

  @override
  int get hashCode => Object.hash(id, syncStatus, cachedAt);
}
