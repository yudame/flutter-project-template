import 'package:hive/hive.dart';

part 'queued_request.g.dart';

@HiveType(typeId: 0)
class QueuedRequest {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final RequestType type;

  @HiveField(2)
  final Map<String, dynamic> params;

  @HiveField(3)
  final DateTime queuedAt;

  @HiveField(4)
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
}

@HiveType(typeId: 1)
enum RequestType {
  @HiveField(0)
  createItem,

  @HiveField(1)
  updateItem,

  @HiveField(2)
  deleteItem,

  // Add your domain-specific request types here
}
