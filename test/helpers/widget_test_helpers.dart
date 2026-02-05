import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_template/l10n/generated/app_localizations.dart';

/// Wraps a widget with MaterialApp and optional BlocProviders for testing
Widget createTestableWidget(
  Widget child, {
  List<BlocProvider> blocProviders = const [],
  Locale locale = const Locale('en'),
}) {
  final Widget app = MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  if (blocProviders.isEmpty) {
    return app;
  }

  return MultiBlocProvider(
    providers: blocProviders,
    child: app,
  );
}

/// Wraps a widget with minimal MaterialApp for simple widget tests
Widget createMinimalTestableWidget(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}
