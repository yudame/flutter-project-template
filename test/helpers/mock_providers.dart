import 'package:flutter_template/core/network/dio_client.dart';
import 'package:flutter_template/core/network/offline_queue.dart';
import 'package:flutter_template/features/home/data/models/item.dart';
import 'package:flutter_template/features/home/data/repositories/item_repository.dart';
import 'package:mocktail/mocktail.dart';

/// Mock DioClient for testing repositories
class MockDioClient extends Mock implements DioClient {}

/// Mock OfflineQueue for testing offline functionality
class MockOfflineQueue extends Mock implements OfflineQueue {}

/// Mock ItemRepository for testing HomeBloc
class MockItemRepository extends Mock implements ItemRepository {}

/// Fake Item for mocktail fallback values
class FakeItem extends Fake implements Item {}
