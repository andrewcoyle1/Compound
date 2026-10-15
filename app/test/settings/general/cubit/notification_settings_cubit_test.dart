import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/settings/general/cubit/notification_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../recorded_analytics.dart';

class _MockUserRepository extends Mock implements UserRepository;

void main() {
  late UserRepository users;
  late RecordedAnalytics analytics;
  late StreamController<PrivateUserSettings?> stored;
  late List<Map<String, Object?>> writes;

  setUpAll(() => registerFallbackValue(const PrivateUserSettings()));

  setUp(() {
    users = _MockUserRepository();
    analytics = RecordedAnalytics();
    stored = StreamController<PrivateUserSettings?>();
    writes = [];
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
  ]) async {
    final cubit = NotificationSettingsCubit(
      users: users,
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
      expect(cubit.state.saveFailed, isTrue);
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
    expect(cubit.state.saveFailed, isFalse);
  });

  test('appearing and disappearing are tracked', () async {
    (await build())
      ..appeared()
      ..disappeared();
    expect(analytics.screenViews, ['NotificationSettingsView_Appear']);
    expect(analytics.names, ['NotificationSettingsView_Disappear']);
  });
}
