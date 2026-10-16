import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart' show ActivityType;
import 'package:equatable/equatable.dart';
import 'package:notifications_repository/notifications_repository.dart';
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

/// What stands between the switches and a delivered push, if anything.
enum PermissionPrompt {
  /// Never asked: explain and offer to ask.
  askFirst,

  /// Refused: only the system settings can turn them back on.
  denied,
}

/// What failed, for the message that says so.
enum NotificationSettingsFailure {
  /// A switch's save failed to start (`Unable to Save Setting`).
  save,

  /// Reading the permission failed.
  checkPermission,

  /// Asking for permission failed.
  requestPermission,
}

/// The private settings the Notification Settings screen shows, read with
/// Swift's defaults (`PrivateUserSettings` extensions), and whether the
/// system lets the app notify.
class const NotificationSettingsState({
  final PrivateUserSettings settings = const PrivateUserSettings(),

  /// The permission, once read.
  final PushPermission? permission,

  /// The last failure, bumped by [failureId] so a repeat shows again.
  final NotificationSettingsFailure? failure,
  final int failureId = 0,
}) extends Equatable {
  /// The prompt above the switches, if any.
  PermissionPrompt? get permissionPrompt => switch (permission) {
    PushPermission.notDetermined => PermissionPrompt.askFirst,
    PushPermission.denied => PermissionPrompt.denied,
    _ => null,
  };

  /// The switches change what the server sends, which arrives only once
  /// the system allows it, so they are usable only then.
  bool get canChangeSwitches => permission?.canDeliver ?? false;

  NotificationSettingsState copyWith({
    PrivateUserSettings? settings,
    PushPermission? permission,
    NotificationSettingsFailure? failure,
  }) => NotificationSettingsState(
    settings: settings ?? this.settings,
    permission: permission ?? this.permission,
    failure: failure ?? this.failure,
    failureId: failure == null ? failureId : failureId + 1,
  );

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
  List<Object?> get props => [
    settings.toFirestore(),
    permission,
    failure,
    failureId,
  ];
}

/// Notification Settings (Swift `NotificationSettingsPresenter`): each
/// switch writes its own key in `users/{uid}/private/settings` the moment it
/// changes, and reads back from the document, so a refused write snaps it
/// back. The switch events keep Swift's `NotificationsView_` names.
///
/// Above the switches, the permission prompt: ask when never asked, point
/// to the system settings when refused; the switches stay off until it is
/// allowed. The come-back and meal reminders are scheduled on the device by
/// `NotificationsCubit`, which follows the same settings document.
class NotificationSettingsCubit extends Cubit<NotificationSettingsState> {
  new({
    required this._users,
    required this._notifications,
    required this._analytics,
    required this._uid,
  }) : super(const NotificationSettingsState()) {
    _subscription = _users
        .watchPrivateSettings(_uid)
        .listen(
          (settings) => emit(
            state.copyWith(settings: settings ?? const PrivateUserSettings()),
          ),
        );
  }

  final UserRepository _users;
  final NotificationsRepository _notifications;
  final AnalyticsRepository _analytics;
  final String _uid;
  late final StreamSubscription<PrivateUserSettings?> _subscription;

  /// `NotificationSettingsView_Appear`.
  void appeared() => _analytics.appear('NotificationSettingsView');

  /// `NotificationSettingsView_Disappear`.
  void disappeared() => _analytics.disappear('NotificationSettingsView');

  /// Reads the permission: on appear, after asking, and on each return to
  /// the app, since the system settings are where a refusal is undone.
  Future<void> checkPermission() async {
    try {
      final permission = await _notifications.permission();
      if (!isClosed) emit(state.copyWith(permission: permission));
    } on Object catch (error) {
      _analytics.severe(
        'NotificationSettingsView_CheckPermissions_Fail',
        error,
      );
      if (!isClosed) {
        emit(
          state.copyWith(failure: NotificationSettingsFailure.checkPermission),
        );
      }
    }
  }

  /// Turn On Notifications: the system prompt, then the status read back,
  /// since the answer changes which rows show.
  Future<void> requestPermissionPressed() async {
    _analytics.analytic('NotificationSettingsView_RequestPermission_Start');
    try {
      final granted = await _notifications.requestPermission();
      _analytics.analytic(
        'NotificationSettingsView_RequestPermission_Success',
        {'granted': granted},
      );
      await checkPermission();
    } on Object catch (error) {
      // A request the user asked for either works or says why.
      _analytics.severe(
        'NotificationSettingsView_RequestPermission_Fail',
        error,
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            failure: NotificationSettingsFailure.requestPermission,
          ),
        );
      }
    }
  }

  /// Open Settings, where a refusal is undone.
  Future<void> openSettingsPressed() => _notifications.openSystemSettings();

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
        emit(state.copyWith(failure: NotificationSettingsFailure.save));
      }
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
