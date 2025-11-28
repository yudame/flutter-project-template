import 'package:flutter_template/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    group('success', () {
      test('creates a success result with data', () {
        const result = Result.success('data');

        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
        expect(result.isLoading, isFalse);
        expect(result.dataOrNull, equals('data'));
        expect(result.errorOrNull, isNull);
      });
    });

    group('failure', () {
      test('creates a failure result with message', () {
        const result = Result<String>.failure('error message');

        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isTrue);
        expect(result.isLoading, isFalse);
        expect(result.dataOrNull, isNull);
        expect(result.errorOrNull, equals('error message'));
      });

      test('creates a failure result with message and error object', () {
        final error = Exception('test');
        final result = Result<String>.failure('error message', error);

        expect(result.isFailure, isTrue);
        result.when(
          success: (_) => fail('Should not be success'),
          failure: (message, err) {
            expect(message, equals('error message'));
            expect(err, equals(error));
          },
          loading: () => fail('Should not be loading'),
        );
      });
    });

    group('loading', () {
      test('creates a loading result', () {
        const result = Result<String>.loading();

        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isFalse);
        expect(result.isLoading, isTrue);
        expect(result.dataOrNull, isNull);
        expect(result.errorOrNull, isNull);
      });
    });

    group('mapSuccess', () {
      test('maps success data to new type', () {
        const result = Result.success(42);
        final mapped = result.mapSuccess((data) => data.toString());

        expect(mapped.dataOrNull, equals('42'));
      });

      test('preserves failure on map', () {
        const result = Result<int>.failure('error');
        final mapped = result.mapSuccess((data) => data.toString());

        expect(mapped.isFailure, isTrue);
        expect(mapped.errorOrNull, equals('error'));
      });

      test('preserves loading on map', () {
        const result = Result<int>.loading();
        final mapped = result.mapSuccess((data) => data.toString());

        expect(mapped.isLoading, isTrue);
      });
    });

    group('execute', () {
      test('calls onSuccess for success result', () {
        const result = Result.success('data');
        var called = false;

        result.execute(
          onSuccess: (data) {
            expect(data, equals('data'));
            called = true;
          },
          onFailure: (_, __) => fail('Should not call onFailure'),
          onLoading: () => fail('Should not call onLoading'),
        );

        expect(called, isTrue);
      });

      test('calls onFailure for failure result', () {
        const result = Result<String>.failure('error');
        var called = false;

        result.execute(
          onSuccess: (_) => fail('Should not call onSuccess'),
          onFailure: (message, _) {
            expect(message, equals('error'));
            called = true;
          },
          onLoading: () => fail('Should not call onLoading'),
        );

        expect(called, isTrue);
      });

      test('calls onLoading for loading result', () {
        const result = Result<String>.loading();
        var called = false;

        result.execute(
          onSuccess: (_) => fail('Should not call onSuccess'),
          onFailure: (_, __) => fail('Should not call onFailure'),
          onLoading: () {
            called = true;
          },
        );

        expect(called, isTrue);
      });
    });
  });
}
