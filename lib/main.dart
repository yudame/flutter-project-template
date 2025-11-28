import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/di/injection.dart';
import 'core/connectivity/connectivity_bloc.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize HydratedBloc storage
  final appDocDir = await getApplicationDocumentsDirectory();
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: appDocDir,
  );

  // Configure dependencies
  await configureDependencies();

  // Run app with or without Sentry based on environment
  if (kReleaseMode) {
    await SentryFlutter.init(
      (options) {
        options.dsn = const String.fromEnvironment('SENTRY_DSN');
        options.tracesSampleRate = 0.2;
        options.environment = const String.fromEnvironment(
          'ENVIRONMENT',
          defaultValue: 'production',
        );
      },
      appRunner: () => runApp(const FlutterTemplateApp()),
    );
  } else {
    runApp(const FlutterTemplateApp());
  }
}

class FlutterTemplateApp extends StatelessWidget {
  const FlutterTemplateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ConnectivityBloc>(
          create: (_) => getIt<ConnectivityBloc>(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Flutter Template',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: appRouter,
      ),
    );
  }
}
