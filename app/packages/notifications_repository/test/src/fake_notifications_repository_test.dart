import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 9);

  // PushPendingDeepLinkTests
  group(DeepLinkInbox, () {
    const sessionData = {
      'tab': 'dashboard',
      'type': 'comment',
      'session_id': 's1',
      'session_author_id': 'u1',
    };

    test('a pending link is consumed exactly once', () {
      final inbox = DeepLinkInbox()
        ..setReady(ready: true)
        ..store(DeepLink.fromData(sessionData));
      expect(
        inbox.consume(),
        const SessionLink(id: 's1', authorId: 'u1', openComments: true),
      );
      expect(inbox.consume(), isNull);
    });

    test('a pending link waits for sign-in, which announces it', () async {
      final inbox = DeepLinkInbox();
      var changes = 0;
      inbox.changes.listen((_) => changes++);
      inbox.store(DeepLink.fromData(const {'type': 'follow_request'}));
      expect(inbox.consume(), isNull);
      expect(inbox.pending, const NotificationsLink());
      expect(changes, 1);

      inbox.setReady(ready: true);
      expect(changes, 2);
      expect(inbox.consume(), const NotificationsLink());
    });

    test('an unknown payload is ignored', () {
      final inbox = DeepLinkInbox()
        ..setReady(ready: true)
        ..store(DeepLink.fromData(const {'tab': 'nutrition'}))
        ..store(DeepLink.fromData(const {'body': 'hello', 'tab': 'sleep'}));
      expect(inbox.consume(), const TabLink(DeepLinkTab.nutrition));
    });

    test('sign-out drops the pending link', () {
      final inbox = DeepLinkInbox()
        ..store(const TabLink(DeepLinkTab.progress))
        ..setReady(ready: false)
        ..setReady(ready: true);
      expect(inbox.consume(), isNull);
    });
  });

  group(PushPermission, () {
    test('only authorized and provisional deliver', () {
      expect(PushPermission.values.where((p) => p.canDeliver), [
        PushPermission.authorized,
        PushPermission.provisional,
      ]);
    });
  });

  test('PushMessage compares by value', () {
    expect(
      const PushMessage(type: 'like', link: NotificationsLink()),
      const PushMessage(type: 'like', link: NotificationsLink()),
    );
  });

  group(FakeNotificationsRepository, () {
    late FakeNotificationsRepository repository;

    setUp(() => repository = FakeNotificationsRepository());

    test('asking grants permission, once', () async {
      await repository.initialize();
      expect(await repository.permission(), PushPermission.notDetermined);
      expect(await repository.requestPermission(), isTrue);
      expect(await repository.permission(), PushPermission.authorized);

      repository.permissionState = PushPermission.denied;
      expect(await repository.requestPermission(), isFalse);
    });

    test('token sync follows sign-in and sign-out', () async {
      await repository.startPushTokenSync('uid');
      expect(repository.tokenUserId, 'uid');
      await repository.stopPushTokenSync();
      expect(repository.tokenUserId, isNull);
    });

    test('the rest timer asks for permission, then schedules', () async {
      final reminder = LocalReminders.restOver(at: now);
      await repository.schedule(reminder);
      expect(repository.permissionState, PushPermission.authorized);
      expect(repository.scheduled, {LocalReminderKind.restOver: reminder});

      await repository.cancel(LocalReminderKind.restOver);
      expect(repository.scheduled, isEmpty);
    });

    test('other reminders do not ask', () async {
      await repository.schedule(
        LocalReminders.idleWorkout(lastLog: now, now: now)!,
      );
      expect(repository.permissionState, PushPermission.notDetermined);
    });

    test('receive and tap stand in for the platform', () {
      final messages = <PushMessage>[];
      repository.foregroundMessages.listen(messages.add);
      repository
        ..receive(const PushMessage(type: 'like'))
        ..deepLinks.setReady(ready: true)
        ..tap(const {'tab': 'social'});
      expect(messages, [const PushMessage(type: 'like')]);
      expect(repository.deepLinks.consume(), const TabLink(DeepLinkTab.social));
    });

    group('applyReminderSettings', () {
      test('without permission it only withdraws', () async {
        await repository.schedule(LocalReminders.comeBack(now).first);
        await repository.applyReminderSettings(
          const PrivateUserSettings(),
          now: now,
        );
        expect(repository.scheduled, isEmpty);
      });

      test('schedules come-back by default and meals once chosen', () async {
        repository.permissionState = PushPermission.authorized;
        await repository.applyReminderSettings(
          const PrivateUserSettings(),
          now: now,
        );
        expect(repository.scheduled.keys, LocalReminderKind.comeBack);
        expect(
          repository.scheduled[LocalReminderKind.comeBack1]!.schedule,
          ReminderAt(now.add(const Duration(days: 1))),
        );

        await repository.applyReminderSettings(
          const PrivateUserSettings(
            pushComeBackReminders: false,
            pushMealReminders: true,
          ),
        );
        expect(repository.scheduled.keys, LocalReminderKind.meals);
      });

      test('leaves the workout reminders alone', () async {
        repository.permissionState = PushPermission.provisional;
        await repository.schedule(LocalReminders.restOver(at: now));
        await repository.applyReminderSettings(
          const PrivateUserSettings(pushComeBackReminders: false),
        );
        expect(repository.scheduled.keys, [LocalReminderKind.restOver]);
      });
    });
  });
}
