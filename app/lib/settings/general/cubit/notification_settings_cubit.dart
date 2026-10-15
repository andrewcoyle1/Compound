import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart' show ActivityType;
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

/// A kind of social push the user can switch off, with the activity type
/// Swift logs it under (`ActivityNotificationModel.ActivityType`).
enum SocialPush {
  likes(ActivityType.like),
  comments(ActivityType.comment),
  mentions(ActivityType.mention),
  follows(ActivityType.follow),
  nudges(ActivityType.nudge),
  shares(ActivityType.share),
  challenges(ActivityType.challengeComplete);

  new(this.type);

  /// The activity type in the toggle's analytics.
  final ActivityType type;

  /// The stored opt-out; absent means on.
  bool? _stored(PrivateUserSettings settings) => switch (this) {
    likes => settings.socialPushLikes,
    comments => settings.socialPushComments,
    mentions => settings.socialPushMentions,
    follows => settings.socialPushFollows,
    nudges => settings.socialPushNudges,
    shares => settings.socialPushShares,
    challenges => settings.socialPushChallenges,
  };

  /// A merge that writes this switch's key, the one `functions/lib.js`
  /// reads (`SOCIAL_PUSH_PREFERENCE_KEYS`), and nothing else.
  PrivateUserSettings _write({required bool isEnabled}) => switch (this) {
    likes => PrivateUserSettings(socialPushLikes: isEnabled),
    comments => PrivateUserSettings(socialPushComments: isEnabled),
    mentions => PrivateUserSettings(socialPushMentions: isEnabled),
    follows => PrivateUserSettings(socialPushFollows: isEnabled),
    nudges => PrivateUserSettings(socialPushNudges: isEnabled),
    shares => PrivateUserSettings(socialPushShares: isEnabled),
    challenges => PrivateUserSettings(socialPushChallenges: isEnabled),
  };
}

/// The private settings the Notification Settings screen shows, read with
/// Swift's defaults (`PrivateUserSettings` extensions).
class const NotificationSettingsState({
  final PrivateUserSettings settings = const PrivateUserSettings(),

  /// The last save failed to start.
  final bool saveFailed = false,
}) extends Equatable {
  /// Swift's and `functions/lib.js`' `DEFAULT_REMINDER_HOUR`.
  static const defaultReminderHour = 19;

  /// On unless switched off.
  bool isSocialPushEnabled(SocialPush push) => push._stored(settings) ?? true;

  /// Off until chosen.
  bool get isStreakReminderEnabled =>
      settings.socialPushStreakReminder ?? false;

  /// The streak reminder's local hour.
  int get reminderHour => settings.reminderHour ?? defaultReminderHour;

  /// On unless switched off.
  bool get isWeeklyDigestEnabled => settings.socialPushWeeklyDigest ?? true;

  /// On unless switched off.
  bool get isComeBackRemindersEnabled => settings.pushComeBackReminders ?? true;

  /// Off until switched on.
  bool get isMealRemindersEnabled => settings.pushMealReminders ?? false;

  @override
  List<Object> get props => [settings.toFirestore(), saveFailed];
}

/// Notification Settings (Swift `NotificationSettingsPresenter`): each
/// switch writes its own key in `users/{uid}/private/settings` the moment it
/// changes, and reads back from the document, so a refused write snaps it
/// back. The switch events keep Swift's `NotificationsView_` names.
///
/// Not ported yet, waiting for the push wiring: the permission prompt and
/// disabling the switches until it is granted, and scheduling or withdrawing
/// the come-back and meal reminders on the device. Only the settings are
/// written, which is what the device reads when it schedules them.
class NotificationSettingsCubit extends Cubit<NotificationSettingsState> {
  new({required this._users, required this._analytics, required this._uid})
    : super(const NotificationSettingsState()) {
    _subscription = _users
        .watchPrivateSettings(_uid)
        .listen(
          (settings) => emit(
            NotificationSettingsState(
              settings: settings ?? const PrivateUserSettings(),
            ),
          ),
        );
  }

  final UserRepository _users;
  final AnalyticsRepository _analytics;
  final String _uid;
  late final StreamSubscription<PrivateUserSettings?> _subscription;

  /// `NotificationSettingsView_Appear`.
  void appeared() => _analytics.appear('NotificationSettingsView');

  /// `NotificationSettingsView_Disappear`.
  void disappeared() => _analytics.disappear('NotificationSettingsView');

  /// A social push switch.
  Future<void> socialPushChanged(SocialPush push, {required bool isEnabled}) =>
      _save('NotificationsView_SocialPush_Toggle', {
        'type': push.type.value,
        'is_enabled': isEnabled,
      }, push._write(isEnabled: isEnabled));

  /// The streak reminder, sent by the server (`streakReminder`).
  Future<void> streakReminderChanged({required bool isEnabled}) => _save(
    'NotificationsView_StreakReminder_Toggle',
    {'is_enabled': isEnabled},
    PrivateUserSettings(socialPushStreakReminder: isEnabled),
  );

  /// The streak reminder's hour, 0 to 23.
  Future<void> reminderHourChanged(int hour) => _save(
    'NotificationsView_ReminderHour_Changed',
    {'hour': hour},
    PrivateUserSettings(reminderHour: hour),
  );

  /// The Sunday digest.
  Future<void> weeklyDigestChanged({required bool isEnabled}) => _save(
    'NotificationsView_WeeklyDigest_Toggle',
    {'is_enabled': isEnabled},
    PrivateUserSettings(socialPushWeeklyDigest: isEnabled),
  );

  /// The come-back reminders.
  Future<void> comeBackRemindersChanged({required bool isEnabled}) => _save(
    'NotificationSettingsView_ComeBackReminders_Toggle',
    {'is_enabled': isEnabled},
    PrivateUserSettings(pushComeBackReminders: isEnabled),
  );

  /// The breakfast, lunch and dinner reminders.
  Future<void> mealRemindersChanged({required bool isEnabled}) => _save(
    'NotificationSettingsView_MealReminders_Toggle',
    {'is_enabled': isEnabled},
    PrivateUserSettings(pushMealReminders: isEnabled),
  );

  Future<void> _save(
    String event,
    Map<String, Object?> parameters,
    PrivateUserSettings change,
  ) async {
    _analytics
      ..analytic(event, parameters)
      ..analytic('NotificationSettingsView_SaveSetting_Start', {
        'setting': event,
      });
    try {
      await _users.mergePrivateSettings(_uid, change);
      _analytics.analytic('NotificationSettingsView_SaveSetting_Success', {
        'setting': event,
      });
    } on Object catch (error) {
      _analytics.severe('NotificationSettingsView_SaveSetting_Fail', error, {
        'setting': event,
      });
      if (!isClosed) {
        emit(
          NotificationSettingsState(settings: state.settings, saveFailed: true),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
