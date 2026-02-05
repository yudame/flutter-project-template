/// Mock API responses for testing
///
/// Use these fixtures when mocking DioClient or API calls in tests.
/// Keep responses minimal but realistic.
class ApiFixtures {
  ApiFixtures._();

  /// Successful items list response
  static const itemsResponse = '''
{
  "data": [
    {
      "id": "1",
      "title": "Item 1",
      "description": "First item description",
      "createdAt": "2024-01-01T00:00:00Z",
      "isCompleted": false
    },
    {
      "id": "2",
      "title": "Item 2",
      "description": null,
      "createdAt": "2024-01-02T00:00:00Z",
      "isCompleted": true
    }
  ]
}
''';

  /// Single item response
  static const singleItemResponse = '''
{
  "data": {
    "id": "1",
    "title": "Item 1",
    "description": "First item description",
    "createdAt": "2024-01-01T00:00:00Z",
    "isCompleted": false
  }
}
''';

  /// Empty list response
  static const emptyResponse = '''
{
  "data": []
}
''';

  /// Generic error response
  static const errorResponse = '''
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Something went wrong"
  }
}
''';

  /// Not found error response
  static const notFoundResponse = '''
{
  "error": {
    "code": "NOT_FOUND",
    "message": "The requested resource was not found"
  }
}
''';

  /// Validation error response
  static const validationErrorResponse = '''
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": {
      "title": "Title is required"
    }
  }
}
''';

  /// Unauthorized error response
  static const unauthorizedResponse = '''
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Authentication required"
  }
}
''';
}
