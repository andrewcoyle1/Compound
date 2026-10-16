import 'package:bloc_test/bloc_test.dart';
import 'package:compound/notifications/notifications.dart';
import 'package:compound/sharing/session_web_link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:user_repository/user_repository.dart';

void main() {
  const uid = 'user-1';
  final now = DateTime(2026, 10, 15, 9);

  late FakeNotificationsRepository notifications;
  late InMemoryUserRepository users;

  NotificationsCubit build() => NotificationsCubit(
    notifications: notifications,
    users: users,
    now: () => now,
  );

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() {
    notifications = FakeNotificationsRepository(
      permissionState: PushPermission.authorized,
    );
    users = InMemoryUserRepository();
  });

  group(NotificationsCubit, () {
    test('signing in syncs the push token and applies the reminders; '
        'signing out retires the token', () async {
      final cubit = build();
      await cubit.userChanged(uid, ready: true);
      await settle();
      expect(notifications.tokenUserId, uid);
      // Come-back reminders are on until turned off; meals are off.
      expect(notifications.scheduled.keys, LocalReminderKind.comeBack);

      await cubit.userChanged(null, ready: false);
      expect(notifications.tokenUserId, isNull);
      await cubit.close();
    });

    test('follows the reminder switches, not every settings write', () async {
      final cubit = build();
      await cubit.userChanged(uid, ready: true);
      await settle();

      await users.mergePrivateSettings(
        uid,
        const PrivateUserSettings(pushMealReminders: true),
      );
      await settle();
      expect(notifications.scheduled.keys, [
        ...LocalReminderKind.comeBack,
        ...LocalReminderKind.meals,
      ]);

      notifications.scheduled.clear();
      await users.mergePrivateSettings(
        uid,
        const PrivateUserSettings(fcmToken: 'token'),
      );
      await settle();
      expect(notifications.scheduled, isEmpty);
      await cubit.close();
    });

    test('returning to the app moves the come-back reminders out', () async {
      final cubit = build();
      await cubit.resumed();
      expect(notifications.scheduled, isEmpty);

      await cubit.userChanged(uid, ready: true);
      await settle();
      notifications.scheduled.clear();
      await cubit.resumed();
      expect(
        notifications.scheduled[LocalReminderKind.comeBack1]!.schedule,
        ReminderAt(now.add(LocalReminders.day)),
      );
      await cubit.close();
    });

    test('settings that cannot be read leave reminders be', () async {
      users = _FailingSettings(throws: true);
      final throwing = build();
      await throwing.userChanged(uid, ready: true);
      expect(notifications.scheduled, isEmpty);
      await throwing.close();

      users = _FailingSettings();
      final cubit = build();
      expect(() async {
        await cubit.userChanged(uid, ready: true);
        await settle();
      }(), completes);
      addTearDown(cubit.close);
    });

    blocTest<NotificationsCubit, NotificationsState>(
      'holds a tap until links can be routed, then routes it once',
      build: build,
      act: (cubit) async {
        notifications.tap(const {'tab': 'nutrition'});
        await cubit.userChanged(uid, ready: false);
        await cubit.userChanged(uid, ready: true);
      },
      expect: () => [
        const NotificationsState(
          link: TabLink(DeepLinkTab.nutrition),
          linkId: 1,
        ),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'routes compound:// links; an unknown one does nothing',
      build: build,
      act: (cubit) async {
        await cubit.userChanged(uid, ready: true);
        cubit
          ..linkOpened(Uri.parse('compound://tab/progress'))
          ..linkOpened(Uri.parse('compound://nowhere'))
          ..linkOpened(Uri.parse('compound://tab/progress'));
      },
      expect: () => const [
        NotificationsState(link: TabLink(DeepLinkTab.progress), linkId: 1),
        NotificationsState(link: TabLink(DeepLinkTab.progress), linkId: 2),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      "routes a workout's web page on the flavor's host as the workout",
      build: () => NotificationsCubit(
        notifications: notifications,
        users: users,
        webLink: SessionWebLink(Uri.parse('https://compound.test/s')),
      ),
      act: (cubit) async {
        await cubit.userChanged(uid, ready: true);
        cubit
          ..linkOpened(Uri.parse('https://example.com/s/user1/abc'))
          ..linkOpened(Uri.parse('https://compound.test/s/user1/abc'))
          ..linkOpened(Uri.parse('compound://tab/progress'));
      },
      expect: () => const [
        NotificationsState(
          link: SessionLink(id: 'abc', authorId: 'user1'),
          linkId: 1,
        ),
        NotificationsState(link: TabLink(DeepLinkTab.progress), linkId: 2),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'signing out drops a link meant for the account leaving',
      build: build,
      act: (cubit) async {
        await cubit.userChanged(uid, ready: true);
        await cubit.userChanged(null, ready: false);
        notifications.tap(const {'tab': 'nutrition'});
        await cubit.userChanged('user-2', ready: false);
        await cubit.userChanged('user-2', ready: true);
        await cubit.userChanged(null, ready: false);
      },
      expect: () => [
        const NotificationsState(
          link: TabLink(DeepLinkTab.nutrition),
          linkId: 1,
        ),
      ],
    );
  });

  group('deepLinkLocation', () {
    const session = SessionLink(id: 's1', authorId: uid);

    test("opens the user's own session in their history", () {
      expect(
        deepLinkLocation(session, currentUserId: uid),
        '/training/history/s1',
      );
      expect(deepLinkLocation(session, currentUserId: 'other'), '/social');
    });

    test('the workout link opens the tracker only when one is under way', () {
      expect(deepLinkLocation(const WorkoutLink()), '/today');
      expect(
        deepLinkLocation(const WorkoutLink(), workoutActive: true),
        '/workout',
      );
    });

    test('a tab link opens the tab', () {
      expect(
        deepLinkLocation(const TabLink(DeepLinkTab.nutrition)),
        '/nutrition',
      );
    });
  });
}

class _FailingSettings extends InMemoryUserRepository {
  new({this.throws = false});

  final bool throws;

  @override
  Stream<PrivateUserSettings?> watchPrivateSettings(String uid) =>
      throws ? throw Exception('denied') : Stream.error(Exception('denied'));
}
