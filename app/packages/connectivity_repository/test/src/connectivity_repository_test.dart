import 'dart:async';

import 'package:connectivity_repository/connectivity_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(ConnectivityRepository, () {
    late StreamController<List<ConnectivityResult>> changes;

    setUp(() => changes = StreamController());

    ConnectivityRepository following(List<ConnectivityResult> now) =>
        ConnectivityRepository(check: () async => now, changes: changes.stream);

    test('is online until it hears otherwise', () async {
      final subject = following(const [ConnectivityResult.none]);
      expect(subject.isOffline, isFalse);
      await pumpEventQueue();
      expect(subject.isOffline, isTrue);
    });

    test(
      'follows each change; offline only when every connection is down',
      () async {
        final subject = following(const [ConnectivityResult.wifi]);
        await pumpEventQueue();
        expect(subject.isOffline, isFalse);

        changes.add(const [ConnectivityResult.none]);
        await pumpEventQueue();
        expect(subject.isOffline, isTrue);

        changes.add(const [ConnectivityResult.none, ConnectivityResult.mobile]);
        await pumpEventQueue();
        expect(subject.isOffline, isFalse);

        // Nothing known: nothing blocked.
        changes
          ..add(const [ConnectivityResult.none])
          ..add(const []);
        await pumpEventQueue();
        expect(subject.isOffline, isFalse);
        await subject.dispose();
      },
    );

    test('a status that cannot be read blocks nothing', () async {
      final subject = ConnectivityRepository(
        check: () => Future.error(StateError('no plugin')),
        changes: Stream.error(StateError('no plugin')),
      );
      await pumpEventQueue();
      expect(subject.isOffline, isFalse);
    });

    test('ensureOnline lets an action through online, and says when it '
        'blocked one', () async {
      final subject = following(const [ConnectivityResult.wifi]);
      final blocked = <void>[];
      subject.blocked.listen(blocked.add);
      await pumpEventQueue();

      expect(subject.ensureOnline(), isTrue);
      changes.add(const [ConnectivityResult.none]);
      await pumpEventQueue();
      expect(subject.ensureOnline(), isFalse);
      await pumpEventQueue();

      expect(blocked, hasLength(1));
    });

    test('follows connectivity_plus by default', () async {
      const methods = MethodChannel('dev.fluttercommunity.plus/connectivity');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methods, (call) async => ['none']);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(methods, null),
      );

      const events = EventChannel(
        'dev.fluttercommunity.plus/connectivity_status',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            events,
            MockStreamHandler.inline(onListen: (_, _) {}),
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockStreamHandler(events, null),
      );

      final subject = ConnectivityRepository();
      await pumpEventQueue();

      expect(subject.isOffline, isTrue);
      await subject.dispose();
    });
  });

  group(FakeConnectivityRepository, () {
    test('is online until told otherwise', () async {
      final subject = FakeConnectivityRepository();
      await pumpEventQueue();
      expect(subject.ensureOnline(), isTrue);
      subject.offline = true;
      expect(subject.ensureOnline(), isFalse);
    });
  });
}
