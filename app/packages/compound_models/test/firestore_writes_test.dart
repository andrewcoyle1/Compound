import 'dart:async';

import 'package:compound_models/compound_models.dart';
import 'package:test/test.dart';

void main() {
  group('writeLocally', () {
    late List<(String, Object)> reported;

    void report(String path, Object error, StackTrace stackTrace) =>
        reported.add((path, error));

    setUp(() => reported = []);

    test('completes when the write does', () async {
      await writeLocally('a/b', () async {}, report);
      expect(reported, isEmpty);
    });

    test('completes while the server never acknowledges', () async {
      final server = Completer<void>();
      await writeLocally('a/b', () => server.future, report);
      expect(server.isCompleted, isFalse);
      expect(reported, isEmpty);
    });

    test('reports a refusal that comes after it completed', () async {
      final server = Completer<void>();
      await writeLocally('a/b', () => server.future, report);

      final error = StateError('permission-denied');
      server.completeError(error);
      await pumpEventQueue();

      expect(reported, [('a/b', error)]);
    });

    test('fails, without reporting, when starting the write throws', () {
      expect(
        writeLocally('a/b', () => throw ArgumentError('bad value'), report),
        throwsArgumentError,
      );
      expect(reported, isEmpty);
    });

    test('fails, without reporting, when the write fails at once', () async {
      await expectLater(
        writeLocally('a/b', () async => throw StateError('local'), report),
        throwsStateError,
      );
      expect(reported, isEmpty);
    });
  });

  test('logWriteError logs without throwing', () {
    expect(
      () => logWriteError('a/b', StateError('x'), StackTrace.current),
      returnsNormally,
    );
  });
}
