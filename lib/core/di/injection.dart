import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/chat/data/repositories/chat_repository.dart';
import '../../features/chat/presentation/bloc/chat_bloc.dart';
import '../../features/home/data/repositories/item_repository.dart';
import '../../features/home/presentation/bloc/home_bloc.dart';
import '../analytics/analytics_service.dart';
import '../analytics/noop_analytics_service.dart';
import '../connectivity/connectivity_bloc.dart';
import '../connectivity/connectivity_service.dart';
import '../database/local_cache_service.dart';
import '../network/auth_token_manager.dart';
import '../network/dio_client.dart';
import '../network/offline_queue.dart';
import '../network/request_executor.dart';
import '../network/streaming_client.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // External dependencies
  final sharedPrefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPrefs);

  getIt.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  );

  getIt.registerLazySingleton<Logger>(
    () => Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 80,
      ),
    ),
  );

  getIt.registerLazySingleton<HiveInterface>(() => Hive);
  getIt.registerLazySingleton<Connectivity>(Connectivity.new);

  // Analytics (use NoopAnalyticsService by default, replace with Firebase in production)
  getIt.registerLazySingleton<AnalyticsService>(
    NoopAnalyticsService.new,
  );

  // Database (local cache — register concrete DatabaseService when choosing a provider)
  getIt.registerLazySingleton<LocalCacheService>(
    () => LocalCacheService(hive: getIt<HiveInterface>()),
  );

  // When using a concrete database service:
  // getIt.registerLazySingleton<DatabaseService>(
  //   () => FirebaseDatabaseService(),
  // );

  // Auth Token Manager
  getIt.registerLazySingleton<AuthTokenManager>(
    () => AuthTokenManager(
      storage: getIt<FlutterSecureStorage>(),
      logger: getIt<Logger>(),
    ),
  );

  // Network
  getIt.registerLazySingleton<Dio>(Dio.new);

  getIt.registerLazySingleton<DioClient>(
    () => DioClient(
      dio: getIt<Dio>(),
      logger: getIt<Logger>(),
      authManager: getIt<AuthTokenManager>(),
    ),
  );

  // Connectivity
  getIt.registerLazySingleton<ConnectivityBloc>(
    () => ConnectivityBloc(
      connectivity: getIt<Connectivity>(),
      dio: getIt<DioClient>().dio,
    ),
  );

  getIt.registerLazySingleton<ConnectivityService>(
    () => ConnectivityServiceImpl(getIt<ConnectivityBloc>()),
  );

  // Offline Queue
  getIt.registerLazySingleton<RequestExecutor>(
    () => RequestExecutor(
      dioClient: getIt<DioClient>(),
      authManager: getIt<AuthTokenManager>(),
    ),
  );

  getIt.registerLazySingleton<OfflineQueue>(
    () => OfflineQueue(
      hive: getIt<HiveInterface>(),
      executor: getIt<RequestExecutor>(),
      logger: getIt<Logger>(),
    ),
  );

  // Streaming (SSE)
  getIt.registerLazySingleton<StreamingClient>(
    () => StreamingClient(
      dioClient: getIt<DioClient>(),
      connectivity: getIt<ConnectivityService>(),
      logger: getIt<Logger>(),
    ),
  );

  // Repositories
  getIt.registerLazySingleton<ItemRepository>(
    () => ItemRepository(
      dioClient: getIt<DioClient>(),
      connectivity: getIt<ConnectivityService>(),
      offlineQueue: getIt<OfflineQueue>(),
      logger: getIt<Logger>(),
    ),
  );

  getIt.registerLazySingleton<ChatRepository>(
    () => ChatRepository(
      streamingClient: getIt<StreamingClient>(),
      logger: getIt<Logger>(),
    ),
  );

  // BLoCs (factories for fresh instances)
  getIt.registerFactory<HomeBloc>(
    () => HomeBloc(
      repository: getIt<ItemRepository>(),
      connectivityBloc: getIt<ConnectivityBloc>(),
    ),
  );

  getIt.registerFactory<ChatBloc>(
    () => ChatBloc(
      repository: getIt<ChatRepository>(),
      connectivityBloc: getIt<ConnectivityBloc>(),
    ),
  );

  // Auth (uncomment after implementing AuthRepository)
  // Import: import '../auth/auth_bloc.dart';
  // Import: import '../auth/auth_repository.dart';
  //
  // getIt.registerLazySingleton<AuthRepository>(
  //   () => FirebaseAuthRepository(tokenManager: getIt<AuthTokenManager>()),
  // );
  //
  // getIt.registerLazySingleton<AuthBloc>(
  //   () => AuthBloc(authRepository: getIt<AuthRepository>()),
  // );
}
