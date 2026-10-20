import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/settings/general/cubit/notification_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../recorded_analytics.dart';

class _MockUserRepository extends Mock implements UserRepository;

class _MockNotifications extends Mock implements NotificationsRepository;

void main() {
  late UserRepository users;
  late RecordedAnalytics analytics;
  late StreamController<PrivateUserSettings?> stored;
  late List<Map<String, Object?>> writes;
  late FakeNotificationsRepository notifications;

  setUpAll(() => registerFallbackValue(const PrivateUserSettings()));

  setUp(() {
    users = _MockUserRepository();
    analytics = RecordedAnalytics();
    stored = StreamController<PrivateUserSettings?>();
    writes = [];
    notifications = FakeNotificationsRepository();
    when(() => users.watchPrivateSettings('uid'))
        .thenAnswer((_) => stored.stream);
    when(() => users.mergePrivateSettings('uid', any()))
        .thenAnswer((invocation) {
          writes.add(
            (invocation.positionalArguments[1] as PrivateUserSettings)
                .toFirestore(),
          );
          return Future.value();
        });
  });

  tearDown(() => stored.close());

  Future<NotificationSettingsCubit> build([
    PrivateUserSettings? settings,
    NotificationsRepository? with_,
  ]) async {
    final cubit = NotificationSettingsCubit(
      users: users,
      notifications: with_ ?? notifications,
      analytics: analytics,
      uid: 'uid',
    );
    stored.add(settings);
    await pumpEventQueue();
    return cubit;
  }

  test('every social switch is on when nothing is stored', () async {
    final cubit = await build();
    expect(SocialPush.values.every(cubit.state.isSocialPushEnabled), isTrue);
  });

  test('each switch reads its own stored key', () async {
    final cubit = await build(
      const PrivateUserSettings(
        socialPushLikes: false,
        socialPushComments: true,
        socialPushMentions: false,
        socialPushFollows: false,
        socialPushNudges: false,
        socialPushShares: false,
        socialPushChallenges: false,
      ),
    );
    expect(
      {
        for (final push in SocialPush.values)
          push: cubit.state.isSocialPushEnabled(push),
      },
      {
        SocialPush.likes: false,
        SocialPush.comments: true,
        SocialPush.mentions: false,
        SocialPush.follows: false,
        SocialPush.nudges: false,
        SocialPush.shares: false,
        SocialPush.challenges: false,
      },
    );
  });

  test('reminder defaults: digest and come-back on, streak and meals off, '
      'hour nineteen', () async {
    final cubit = await build();
    expect(cubit.state.isStreakReminderEnabled, isFalse);
    expect(cubit.state.isWeeklyDigestEnabled, isTrue);
    expect(cubit.state.isComeBackRemindersEnabled, isTrue);
    expect(cubit.state.isMealRemindersEnabled, isFalse);
    expect(cubit.state.reminderHour, 19);
  });

  test('each social switch writes its own key and nothing else', () async {
    final cubit = await build();
    for (final push in SocialPush.values) {
      await cubit.socialPushChanged(push, isEnabled: false);
    }
    expect(writes, [
      {'social_push_likes': false},
      {'social_push_comments': false},
      {'social_push_mentions': false},
      {'social_push_follows': false},
      {'social_push_nudges': false},
      {'social_push_shares': false},
      {'social_push_challenges': false},
    ]);
  });

  test('the social push event keeps its Swift name and parameters', () async {
    final cubit = await build();
    await cubit.socialPushChanged(SocialPush.challenges, isEnabled: false);
    expect(analytics.events, [
      [
        'NotificationsView_SocialPush_Toggle',
        {'type': 'challenge_complete', 'is_enabled': false},
        LogType.analytic,
      ],
      [
        'NotificationSettingsView_SaveSetting_Start',
        {'setting': 'NotificationsView_SocialPush_Toggle'},
        LogType.analytic,
      ],
      [
        'NotificationSettingsView_SaveSetting_Success',
        {'setting': 'NotificationsView_SocialPush_Toggle'},
        LogType.analytic,
      ],
    ]);
  });

  test(
    'each reminder control writes the key the server or device reads',
    () async {
      final cubit = await build();
      await cubit.streakReminderChanged(isEnabled: true);
      await cubit.reminderHourChanged(7);
      await cubit.weeklyDigestChanged(isEnabled: false);
      await cubit.comeBackRemindersChanged(isEnabled: false);
      await cubit.mealRemindersChanged(isEnabled: true);
      expect(writes, [
        {'social_push_streak_reminder': true},
        {'reminder_hour': 7},
        {'social_push_weekly_digest': false},
        {'push_come_back_reminders': false},
        {'push_meal_reminders': true},
      ]);
      expect(analytics.names.where((name) => !name.contains('_SaveSetting_')), [
        'NotificationsView_StreakReminder_Toggle',
        'NotificationsView_ReminderHour_Changed',
        'NotificationsView_WeeklyDigest_Toggle',
        'NotificationSettingsView_ComeBackReminders_Toggle',
        'NotificationSettingsView_MealReminders_Toggle',
      ]);
      expect(analytics.events[3][1], {'hour': 7});
    },
  );

  test('the switches follow the stored document', () async {
    final cubit = await build();
    stored.add(
      const PrivateUserSettings(
        socialPushStreakReminder: true,
        reminderHour: 7,
        socialPushWeeklyDigest: false,
        pushComeBackReminders: false,
        pushMealReminders: true,
      ),
    );
    await pumpEventQueue();
    expect(cubit.state.isStreakReminderEnabled, isTrue);
    expect(cubit.state.reminderHour, 7);
    expect(cubit.state.isWeeklyDigestEnabled, isFalse);
    expect(cubit.state.isComeBackRemindersEnabled, isFalse);
    expect(cubit.state.isMealRemindersEnabled, isTrue);
  });

  test(
    'a failed write says so, and the switch keeps the stored value',
    () async {
      when(() => users.mergePrivateSettings(any(), any()))
          .thenThrow(StateError('no'));
      final cubit = await build();
      await cubit.socialPushChanged(SocialPush.likes, isEnabled: false);
      expect(cubit.state.failure, NotificationSettingsFailure.save);
      expect(cubit.state.isSocialPushEnabled(SocialPush.likes), isTrue);
      expect(
        analytics.events.last[0],
        'NotificationSettingsView_SaveSetting_Fail',
      );
      expect(analytics.events.last[2], LogType.severe);
      expect(
        (analytics.events.last[1]! as Map)['setting'],
        'NotificationsView_SocialPush_Toggle',
      );
    },
  );

  test('a write that fails after closing emits nothing', () async {
    final refusal = Completer<void>();
    when(() => users.mergePrivateSettings(any(), any()))
        .thenAnswer((_) => refusal.future);
    final cubit = await build();
    final saving = cubit.mealRemindersChanged(isEnabled: true);
    await cubit.close();
    refusal.completeError(StateError('no'));
    await saving;
    expect(cubit.state.failure, isNull);
  });

  test('appearing and disappearing are tracked', () async {
    (await build())
      ..appeared()
      ..disappeared();
    expect(analytics.screenViews, ['NotificationSettingsView_Appear']);
    expect(analytics.names, ['NotificationSettingsView_Disappear']);
  });

  group('permission (NotificationSettingsPresenterTests)', () {
    test(
      'an unasked permission offers to ask and disables the switches',
      () async {
        final cubit = await build();
        await cubit.checkPermission();
        expect(cubit.state.permissionPrompt, PermissionPrompt.askFirst);
        expect(cubit.state.canChangeSwitches, isFalse);
      },
    );

    test(
      'a denied permission points to Settings and disables the switches',
      () async {
        notifications.permissionState = PushPermission.denied;
        final cubit = await build();
        await cubit.checkPermission();
        expect(cubit.state.permissionPrompt, PermissionPrompt.denied);
        expect(cubit.state.canChangeSwitches, isFalse);
        await cubit.openSettingsPressed();
        expect(notifications.settingsOpened, 1);
      },
    );

    for (final permission in [
      PushPermission.authorized,
      PushPermission.provisional,
    ]) {
      test('an allowed permission ($permission) shows no prompt and enables '
          'the switches', () async {
        notifications.permissionState = permission;
        final cubit = await build();
        await cubit.checkPermission();
        expect(cubit.state.permissionPrompt, isNull);
        expect(cubit.state.canChangeSwitches, isTrue);
      });
    }

    test('until it is read, no prompt shows and the switches wait', () async {
      final cubit = await build();
      expect(cubit.state.permissionPrompt, isNull);
      expect(cubit.state.canChangeSwitches, isFalse);
    });

    test('granting permission enables the switches immediately', () async {
      final cubit = await build();
      await cubit.checkPermission();
      await cubit.requestPermissionPressed();
      expect(cubit.state.canChangeSwitches, isTrue);
      expect(analytics.events, [
        [
          'NotificationSettingsView_RequestPermission_Start',
          null,
          LogType.analytic,
        ],
        [
          'NotificationSettingsView_RequestPermission_Success',
          {'granted': true},
          LogType.analytic,
        ],
      ]);
    });

    test('a failed permission request is not swallowed', () async {
      final failing = _MockNotifications();
      when(failing.requestPermission).thenThrow(StateError('no'));
      final cubit = await build(null, failing);
      await cubit.requestPermissionPressed();
      expect(
        cubit.state.failure,
        NotificationSettingsFailure.requestPermission,
      );
      expect(
        analytics.events.last[0],
        'NotificationSettingsView_RequestPermission_Fail',
      );
      expect(analytics.events.last[2], LogType.severe);
    });

    test('a failed permission check is reported', () async {
      final failing = _MockNotifications();
      when(failing.permission).thenThrow(StateError('no'));
      final cubit = await build(null, failing);
      await cubit.checkPermission();
      await cubit.checkPermission();
      expect(cubit.state.failure, NotificationSettingsFailure.checkPermission);
      // Each failure is told again.
      expect(cubit.state.failureId, 2);
      expect(
        analytics.events.last[0],
        'NotificationSettingsView_CheckPermissions_Fail',
      );
    });

    test('a successful permission check says nothing', () async {
      final cubit = await build();
      await cubit.checkPermission();
      expect(cubit.state.failure, isNull);
      expect(analytics.events, isEmpty);
    });

    test('a check or request that ends after closing emits nothing', () async {
      final failing = _MockNotifications();
      final answer = Completer<PushPermission>();
      final asked = Completer<bool>();
      when(failing.permission).thenAnswer((_) => answer.future);
      when(failing.requestPermission).thenAnswer((_) => asked.future);
      final cubit = await build(null, failing);
      final checking = cubit.checkPermission();
      final requesting = cubit.requestPermissionPressed();
      await cubit.close();
      answer.completeError(StateError('no'));
      asked.completeError(StateError('no'));
      await checking;
      await requesting;
      expect(cubit.state.failure, isNull);
    });

    test('returning re-reads the permission', () async {
      final cubit = await build();
      await cubit.checkPermission();
      notifications.permissionState = PushPermission.authorized;
      await cubit.checkPermission();
      expect(cubit.state.canChangeSwitches, isTrue);
    });
  });
}
