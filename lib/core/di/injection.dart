import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../connectivity/connectivity_bloc.dart';
import '../connectivity/connectivity_service.dart';
import '../network/auth_token_manager.dart';
import '../network/dio_client.dart';
import '../network/offline_queue.dart';
import '../network/request_executor.dart';
import '../../features/home/data/repositories/item_repository.dart';
import '../../features/home/presentation/bloc/home_bloc.dart';

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
        colors: true,
        printEmojis: true,
      ),
    ),
  );

  getIt.registerLazySingleton<HiveInterface>(() => Hive);
  getIt.registerLazySingleton<Connectivity>(() => Connectivity());

  // Auth Token Manager
  getIt.registerLazySingleton<AuthTokenManager>(
    () => AuthTokenManager(
      storage: getIt<FlutterSecureStorage>(),
      logger: getIt<Logger>(),
    ),
  );

  // Network
  getIt.registerLazySingleton<Dio>(() => Dio());

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

  // Repositories
  getIt.registerLazySingleton<ItemRepository>(
    () => ItemRepository(
      dioClient: getIt<DioClient>(),
      connectivity: getIt<ConnectivityService>(),
      offlineQueue: getIt<OfflineQueue>(),
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
}
