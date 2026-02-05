import '../utils/result.dart';

/// Abstract database service interface.
///
/// Implement for your backend: Firebase, Supabase, REST API, etc.
/// Repositories depend on this interface, not concrete implementations.
///
/// See `docs/database.md` for provider setup guides and usage patterns.
///
/// Example (Firebase):
/// ```dart
/// class FirebaseDatabaseService implements DatabaseService {
///   final FirebaseFirestore _firestore;
///   // ... see docs/database.md for full implementation
/// }
/// ```
abstract class DatabaseService {
  /// Get a single document by ID.
  ///
  /// Returns the document as a raw JSON map with an `id` field included.
  Future<Result<Map<String, dynamic>>> get(String collection, String id);

  /// Query documents in a collection with optional filters and ordering.
  ///
  /// Example:
  /// ```dart
  /// final result = await db.query(
  ///   'items',
  ///   filters: [
  ///     QueryFilter(field: 'userId', operator: QueryOperator.equals, value: uid),
  ///   ],
  ///   orderBy: 'createdAt',
  ///   descending: true,
  ///   limit: 20,
  /// );
  /// ```
  Future<Result<List<Map<String, dynamic>>>> query(
    String collection, {
    List<QueryFilter>? filters,
    String? orderBy,
    bool descending = false,
    int? limit,
  });

  /// Create or update a document.
  ///
  /// If [id] is null, the backend should auto-generate an ID.
  /// Returns the document ID on success.
  Future<Result<String>> set(
    String collection,
    Map<String, dynamic> data, {
    String? id,
  });

  /// Delete a document by ID.
  Future<Result<void>> delete(String collection, String id);

  /// Watch a single document for real-time updates.
  ///
  /// Returns a stream that emits whenever the document changes.
  /// Not all backends support this — REST APIs may throw [UnsupportedError].
  Stream<Result<Map<String, dynamic>>> watch(String collection, String id);

  /// Watch a collection query for real-time updates.
  ///
  /// Returns a stream that emits whenever matching documents change.
  /// Not all backends support this — REST APIs may throw [UnsupportedError].
  Stream<Result<List<Map<String, dynamic>>>> watchQuery(
    String collection, {
    List<QueryFilter>? filters,
    String? orderBy,
    bool descending = false,
    int? limit,
  });
}

/// Filter for database queries.
///
/// Combines a field name, operator, and value for query conditions.
class QueryFilter {
  /// The document field to filter on.
  final String field;

  /// The comparison operator.
  final QueryOperator operator;

  /// The value to compare against.
  final dynamic value;

  const QueryFilter({
    required this.field,
    required this.operator,
    required this.value,
  });

  @override
  String toString() => 'QueryFilter($field ${operator.name} $value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryFilter &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          operator == other.operator &&
          value == other.value;

  @override
  int get hashCode => Object.hash(field, operator, value);
}

/// Supported query operators for [QueryFilter].
enum QueryOperator {
  /// Equal to (==)
  equals,

  /// Not equal to (!=)
  notEquals,

  /// Less than (<)
  lessThan,

  /// Less than or equal to (<=)
  lessThanOrEquals,

  /// Greater than (>)
  greaterThan,

  /// Greater than or equal to (>=)
  greaterThanOrEquals,

  /// Array contains value
  contains,

  /// Array contains any of the values
  containsAny,
}
