import 'package:flutter/material.dart';
import 'package:flutter_template/shared/widgets/error_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorView', () {
    testWidgets('displays error message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorView(message: 'Test error message'),
          ),
        ),
      );

      expect(find.text('Test error message'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('displays retry button when onRetry is provided', (tester) async {
      var retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              message: 'Error',
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryPressed, isTrue);
    });

    testWidgets('hides retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorView(message: 'Error'),
          ),
        ),
      );

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('displays custom icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorView(
              message: 'No connection',
              icon: Icons.wifi_off,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });
}
