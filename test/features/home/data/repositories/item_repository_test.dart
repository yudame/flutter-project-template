import 'package:dio/dio.dart';
import 'package:flutter_template/core/connectivity/connectivity_service.dart';
import 'package:flutter_template/core/connectivity/connectivity_state.dart';
import 'package:flutter_template/core/database/local_cache_service.dart';
import 'package:flutter_template/core/network/dio_client.dart';
import 'package:flutter_template/core/network/offline_queue.dart';
import 'package:flutter_template/core/network/queued_request.dart';
import 'package:flutter_template/core/utils/result.dart';
import 'package:flutter_template/features/home/data/models/item.dart';
import 'package:flutter_template/features/home/data/repositories/item_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class MockDioClient extends Mock implements DioClient {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockOfflineQueue extends Mock implements OfflineQueue {}

class MockLocalCacheService extends Mock implements LocalCacheService {}

class MockLogger extends Mock implements Logger {}

void main() {
  late ItemRepository repository;
  late MockDioClient mockDioClient;
  late MockConnectivityService mockConnectivity;
  late MockOfflineQueue mockOfflineQueue;
  late MockLocalCacheService mockLocalCache;
  late MockLogger mockLogger;

  final testItems = [
    Item(
      id: '1',
      title: 'Item 1',
      description: 'First test item',
      createdAt: DateTime(2026, 1, 1),
    ),
    Item(
      id: '2',
      title: 'Item 2',
      description: 'Second test item',
      createdAt: DateTime(2026, 1, 2),
    ),
  ];

  setUp(() {
    mockDioClient = MockDioClient();
    mockConnectivity = MockConnectivityService();
    mockOfflineQueue = MockOfflineQueue();
    mockLocalCache = MockLocalCacheService();
    mockLogger = MockLogger();

    repository = ItemRepository(
      dioClient: mockDioClient,
      connectivity: mockConnectivity,
      offlineQueue: mockOfflineQueue,
      localCache: mockLocalCache,
      logger: mockLogger,
    );
  });

  group('ItemRepository', () {
    group('getItems', () {
      test('fetches from API and caches locally when online', () async {
        when(() => mockConnectivity.currentState)
            .thenReturn(const ConnectivityState.online());
        when(() => mockDioClient.get<List<dynamic>>('/items')).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/items'),
            data: testItems.map((e) => e.toJson()).toList(),
          ),
        );
        when(() => mockLocalCache.putAll('items', any()))
            .thenAnswer((_) async {});

        final result = await repository.getItems();

        expect(result, isA<Success<List<Item>>>());
        final items = (result as Success<List<Item>>).data;
        expect(items.length, equals(2));
        expect(items.first.title, equals('Item 1'));
        verify(() => mockDioClient.get<List<dynamic>>('/items')).called(1);
        verify(() => mockLocalCache.putAll('items', any())).called(1);
      });

      test('fetches from local cache when offline', () async {
        when(() => mockConnectivity.currentState)
            .thenReturn(const ConnectivityState.offline());
        when(() => mockLocalCache.getAll('items')).thenAnswer(
          (_) async => Result.success(
            testItems.map((e) => e.toJson()).toList(),
          ),
        );

        final result = await repository.getItems();

        expect(result, isA<Success<List<Item>>>());
        final items = (result as Success<List<Item>>).data;
        expect(items.length, equals(2));
        verifyNever(() => mockDioClient.get<List<dynamic>>(any()));
        verify(() => mockLocalCache.getAll('items')).called(1);
      });

      test('returns failure when offline and cache is empty', () async {
        when(() => mockConnectivity.currentState)
            .thenReturn(const ConnectivityState.offline());
        when(() => mockLocalCache.getAll('items')).thenAnswer(
          (_) async => const Result.success([]),
        );

        final result = await repository.getItems();

        expect(result, isA<Failure<List<Item>>>());
      });
    });

    group('createItem', () {
      test('queues and persists optimistically when offline', () async {
        when(() => mockConnectivity.isOffline).thenReturn(true);
        when(() => mockOfflineQueue.add(RequestType.createItem, any()))
            .thenAnswer((_) async {});
        when(() => mockLocalCache.put('items', any(), any()))
            .thenAnswer((_) async {});

        final result = await repository.createItem(
          title: 'Offline Note',
          description: 'Offline Desc',
        );

        expect(result, isA<Success<Item>>());
        final item = (result as Success<Item>).data;
        expect(item.title, equals('Offline Note'));
        verify(() => mockOfflineQueue.add(RequestType.createItem, any())).called(1);
        verify(() => mockLocalCache.put('items', any(), any())).called(1);
      });
    });

    group('deleteItem', () {
      test('deletes via API and removes from cache when online', () async {
        when(() => mockConnectivity.isOffline).thenReturn(false);
        when(() => mockDioClient.delete('/items/1')).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/items/1'),
            statusCode: 204,
          ),
        );
        when(() => mockLocalCache.remove('items', '1'))
            .thenAnswer((_) async {});

        final result = await repository.deleteItem('1');

        expect(result, isA<Success<void>>());
        verify(() => mockDioClient.delete('/items/1')).called(1);
        verify(() => mockLocalCache.remove('items', '1')).called(1);
      });
    });
  });
}
