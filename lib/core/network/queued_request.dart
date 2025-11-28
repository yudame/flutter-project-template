/// Request type for offline queue operations.
enum RequestType {
  createItem,
  updateItem,
  deleteItem,
  // Add your domain-specific request types here
}

/// Represents a queued request for offline execution.
class QueuedRequest {
  final String id;
  final RequestType type;
  final Map<String, dynamic> params;
  final DateTime queuedAt;
  final int retryCount;

  const QueuedRequest({
    required this.id,
    required this.type,
    required this.params,
    required this.queuedAt,
    this.retryCount = 0,
  });

  QueuedRequest copyWith({
    String? id,
    RequestType? type,
    Map<String, dynamic>? params,
    DateTime? queuedAt,
    int? retryCount,
  }) {
    return QueuedRequest(
      id: id ?? this.id,
      type: type ?? this.type,
      params: params ?? this.params,
      queuedAt: queuedAt ?? this.queuedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  /// Convert to JSON for persistence.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'params': params,
        'queuedAt': queuedAt.toIso8601String(),
        'retryCount': retryCount,
      };

  /// Create from JSON.
  factory QueuedRequest.fromJson(Map<String, dynamic> json) {
    return QueuedRequest(
      id: json['id'] as String,
      type: RequestType.values.byName(json['type'] as String),
      params: Map<String, dynamic>.from(json['params'] as Map),
      queuedAt: DateTime.parse(json['queuedAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }
}
