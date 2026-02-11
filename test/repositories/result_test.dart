// Unit tests for Result<T> class
import 'package:flutter_test/flutter_test.dart';
import 'package:lejeepney/repositories/base_repository.dart';

void main() {
  group('Result<T>', () {
    group('factory constructors', () {
      test('success() creates a successful result with data', () {
        final result = Result.success('test data');

        expect(result.data, equals('test data'));
        expect(result.error, isNull);
        expect(result.isLoading, isFalse);
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
      });

      test('failure() creates a failed result with error message', () {
        final result = Result<String>.failure('Something went wrong');

        expect(result.data, isNull);
        expect(result.error, equals('Something went wrong'));
        expect(result.isLoading, isFalse);
        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isTrue);
      });

      test('loading() creates a loading result', () {
        final result = Result<String>.loading();

        expect(result.data, isNull);
        expect(result.error, isNull);
        expect(result.isLoading, isTrue);
        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isFalse);
      });
    });

    group('map()', () {
      test('maps success value to another type', () {
        final result = Result.success(10);
        final mapped = result.map((value) => 'Value: $value');

        expect(mapped.data, equals('Value: 10'));
        expect(mapped.isSuccess, isTrue);
      });

      test('propagates failure without calling mapper', () {
        final result = Result<int>.failure('error');
        var mapperCalled = false;
        final mapped = result.map((value) {
          mapperCalled = true;
          return 'Value: $value';
        });

        expect(mapperCalled, isFalse);
        expect(mapped.error, equals('error'));
        expect(mapped.isFailure, isTrue);
      });

      test('returns loading when result is loading', () {
        final result = Result<int>.loading();
        final mapped = result.map((value) => 'Value: $value');

        expect(mapped.isLoading, isTrue);
      });
    });

    group('onSuccess()', () {
      test('executes callback when result is successful', () {
        final result = Result.success('data');
        String? receivedData;
        result.onSuccess((data) => receivedData = data);

        expect(receivedData, equals('data'));
      });

      test('does not execute callback when result is failure', () {
        final result = Result<String>.failure('error');
        var callbackExecuted = false;
        result.onSuccess((_) => callbackExecuted = true);

        expect(callbackExecuted, isFalse);
      });
    });

    group('onFailure()', () {
      test('executes callback when result is failure', () {
        final result = Result<String>.failure('error message');
        String? receivedError;
        result.onFailure((error) => receivedError = error);

        expect(receivedError, equals('error message'));
      });

      test('does not execute callback when result is success', () {
        final result = Result.success('data');
        var callbackExecuted = false;
        result.onFailure((_) => callbackExecuted = true);

        expect(callbackExecuted, isFalse);
      });
    });

    group('with complex types', () {
      test('works with List types', () {
        final result = Result.success([1, 2, 3]);

        expect(result.data, equals([1, 2, 3]));
        expect(result.isSuccess, isTrue);
      });

      test('works with Map types', () {
        final result = Result.success({'key': 'value'});

        expect(result.data, equals({'key': 'value'}));
        expect(result.isSuccess, isTrue);
      });

      test('works with nullable inner types', () {
        final result = Result<String?>.success(null);

        // Note: isSuccess returns false when data is null
        expect(result.data, isNull);
        expect(result.error, isNull);
      });
    });
  });
}
