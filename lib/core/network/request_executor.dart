import 'package:dio/dio.dart';

import 'auth_token_manager.dart';
import 'dio_client.dart';
import 'queued_request.dart';

class RequestExecutor {
  final DioClient _dioClient;
  final AuthTokenManager _authManager;

  RequestExecutor({
    required DioClient dioClient,
    required AuthTokenManager authManager,
  })  : _dioClient = dioClient,
        _authManager = authManager;

  Future<void> execute(QueuedRequest request) async {
    switch (request.type) {
      case RequestType.createItem:
        return _executeCreate(request.params);
      case RequestType.updateItem:
        return _executeUpdate(request.params);
      case RequestType.deleteItem:
        return _executeDelete(request.params);
    }
  }

  Future<void> _executeCreate(Map<String, dynamic> params) async {
    final token = await _getValidAuthToken();
    await _dioClient.post(
      '/items',
      data: params,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> _executeUpdate(Map<String, dynamic> params) async {
    final token = await _getValidAuthToken();
    final id = params['id'] as String;
    await _dioClient.put(
      '/items/$id',
      data: params,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> _executeDelete(Map<String, dynamic> params) async {
    final token = await _getValidAuthToken();
    final id = params['id'] as String;
    await _dioClient.delete(
      '/items/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<String> _getValidAuthToken() async {
    if (await _authManager.isTokenExpired()) {
      return await _authManager.refreshAccessToken();
    }
    return await _authManager.getAccessToken() ?? '';
  }
}
