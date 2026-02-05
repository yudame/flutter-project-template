import 'dart:convert';

import 'package:flutter_template/core/database/local_cache_service.dart';
import 'package:flutter_template/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockHiveInterface extends Mock implements HiveInterface {}

class MockBox extends Mock implements Box<String> {}

void main() {
  late MockHiveInterface mockHive;
  late MockBox mockBox;
  late LocalCacheService cache;

  setUp(() {
    mockHive = MockHiveInterface();
    mockBox = MockBox();
    cache = LocalCacheService(hive: mockHive);

    // Default: box is not already open, openBox returns mock
    when(() => mockHive.isBoxOpen(any())).thenReturn(false);
    when(() => mockHive.openBox<String>(any()))
        .thenAnswer((_) async => mockBox);
  });

  group('LocalCacheService', () {
    group('get', () {
      test('returns document when found', () async {
        final data = {'id': '1', 'title': 'Test'};
        when(() => mockBox.get('1')).thenReturn(jsonEncode(data));

        final result = await cache.get('items', '1');

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, equals(data));
        verify(() => mockHive.openBox<String>('cache_items')).called(1);
      });

      test('returns null when document not found', () async {
        when(() => mockBox.get('missing')).thenReturn(null);

        final result = await cache.get('items', 'missing');

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isNull);
      });

      test('returns failure on error', () async {
        when(() => mockBox.get(any())).thenThrow(Exception('disk error'));

        final result = await cache.get('items', '1');

        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, contains('Cache read failed'));
      });
    });

    group('getAll', () {
      test('returns all documents in collection', () async {
        final doc1 = {'id': '1', 'title': 'First'};
        final doc2 = {'id': '2', 'title': 'Second'};
        when(() => mockBox.values)
            .thenReturn([jsonEncode(doc1), jsonEncode(doc2)]);

        final result = await cache.getAll('items');

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, hasLength(2));
        expect(result.dataOrNull![0], equals(doc1));
        expect(result.dataOrNull![1], equals(doc2));
      });

      test('returns empty list when no documents cached', () async {
        when(() => mockBox.values).thenReturn([]);

        final result = await cache.getAll('items');

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isEmpty);
      });

      test('returns failure on error', () async {
        when(() => mockBox.values).thenThrow(Exception('disk error'));

        final result = await cache.getAll('items');

        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, contains('Cache read failed'));
      });
    });

    group('put', () {
      test('stores document as JSON string', () async {
        final data = {'id': '1', 'title': 'Test'};
        when(() => mockBox.put(any(), any())).thenAnswer((_) async {});

        await cache.put('items', '1', data);

        verify(() => mockBox.put('1', jsonEncode(data))).called(1);
      });
    });

    group('putAll', () {
      test('stores multiple documents', () async {
        final docs = {
          '1': {'id': '1', 'title': 'First'},
          '2': {'id': '2', 'title': 'Second'},
        };
        when(() => mockBox.putAll(any())).thenAnswer((_) async {});

        await cache.putAll('items', docs);

        final captured =
            verify(() => mockBox.putAll(captureAny())).captured.single
                as Map<dynamic, dynamic>;
        expect(captured.length, equals(2));
        expect(jsonDecode(captured['1'] as String), equals(docs['1']));
        expect(jsonDecode(captured['2'] as String), equals(docs['2']));
      });
    });

    group('remove', () {
      test('deletes document from cache', () async {
        when(() => mockBox.delete(any())).thenAnswer((_) async {});

        await cache.remove('items', '1');

        verify(() => mockBox.delete('1')).called(1);
      });
    });

    group('clear', () {
      test('clears all documents in collection', () async {
        when(() => mockBox.clear()).thenAnswer((_) async => 0);

        await cache.clear('items');

        verify(() => mockBox.clear()).called(1);
      });
    });

    group('exists', () {
      test('returns true when document exists', () async {
        when(() => mockBox.containsKey('1')).thenReturn(true);

        final result = await cache.exists('items', '1');

        expect(result, isTrue);
      });

      test('returns false when document does not exist', () async {
        when(() => mockBox.containsKey('missing')).thenReturn(false);

        final result = await cache.exists('items', 'missing');

        expect(result, isFalse);
      });
    });

    group('count', () {
      test('returns number of cached documents', () async {
        when(() => mockBox.length).thenReturn(5);

        final result = await cache.count('items');

        expect(result, equals(5));
      });

      test('returns zero for empty collection', () async {
        when(() => mockBox.length).thenReturn(0);

        final result = await cache.count('items');

        expect(result, equals(0));
      });
    });

    group('box management', () {
      test('uses existing open box instead of reopening', () async {
        when(() => mockHive.isBoxOpen('cache_items')).thenReturn(true);
        when(() => mockHive.box<String>('cache_items')).thenReturn(mockBox);
        when(() => mockBox.get('1')).thenReturn(null);

        await cache.get('items', '1');

        verify(() => mockHive.box<String>('cache_items')).called(1);
        verifyNever(() => mockHive.openBox<String>(any()));
      });

      test('each collection gets its own box name', () async {
        when(() => mockBox.get(any())).thenReturn(null);

        await cache.get('items', '1');
        verify(() => mockHive.openBox<String>('cache_items')).called(1);

        await cache.get('users', '1');
        verify(() => mockHive.openBox<String>('cache_users')).called(1);
      });
    });
  });
}
