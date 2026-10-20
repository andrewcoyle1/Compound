/// Field names of `users/{uid}/private/settings`, exactly as the Swift
/// `CodingKeys` spell them.
///
/// Partial updates take their field names only from here.
abstract final class PrivateUserSettingsKeys {
  /// `fcm_token`.
  static const fcmToken = 'fcm_token';

  /// `social_push_likes`.
  static const socialPushLikes = 'social_push_likes';

  /// `social_push_comments`.
  static const socialPushComments = 'social_push_comments';

  /// `social_push_follows`.
  static const socialPushFollows = 'social_push_follows';

  /// `social_push_nudges`.
  static const socialPushNudges = 'social_push_nudges';

  /// `social_push_mentions`.
  static const socialPushMentions = 'social_push_mentions';

  /// `social_push_shares`.
  static const socialPushShares = 'social_push_shares';

  /// `reminder_hour`.
  static const reminderHour = 'reminder_hour';

  /// `timezone`.
  static const timezone = 'timezone';

  /// `social_push_streak_reminder`.
  static const socialPushStreakReminder = 'social_push_streak_reminder';

  /// `social_push_weekly_digest`.
  static const socialPushWeeklyDigest = 'social_push_weekly_digest';

  /// `week_streak`.
  static const weekStreak = 'week_streak';

  /// `week_sessions`.
  static const weekSessions = 'week_sessions';

  /// `week_goal`.
  static const weekGoal = 'week_goal';

  /// `week_ends_at`.
  static const weekEndsAt = 'week_ends_at';

  /// `last_trained_at`.
  static const lastTrainedAt = 'last_trained_at';

  /// `social_push_challenges`.
  static const socialPushChallenges = 'social_push_challenges';

  /// `push_come_back_reminders`.
  static const pushComeBackReminders = 'push_come_back_reminders';

  /// `push_meal_reminders`.
  static const pushMealReminders = 'push_meal_reminders';

  /// `coach_consent`.
  static const coachConsent = 'coach_consent';

  /// `coach_consent_at`.
  static const coachConsentAt = 'coach_consent_at';

  /// Every field, in declaration order.
  static const List<String> all = [
    fcmToken,
    socialPushLikes,
    socialPushComments,
    socialPushFollows,
    socialPushNudges,
    socialPushMentions,
    socialPushShares,
    reminderHour,
    timezone,
    socialPushStreakReminder,
    socialPushWeeklyDigest,
    weekStreak,
    weekSessions,
    weekGoal,
    weekEndsAt,
    lastTrainedAt,
    socialPushChallenges,
    pushComeBackReminders,
    pushMealReminders,
    coachConsent,
    coachConsentAt,
  ];
}

/// The owner-only document at `users/{uid}/private/settings`.
/// Every field is optional.
///
/// Mirrors the Swift `PrivateUserSettings`
/// (`Compound/Managers/User/Models/`).
class const PrivateUserSettings({
  /// The push token.
  final String? fcmToken,

  /// Push for likes; absent means on.
  final bool? socialPushLikes,

  /// Push for comments; absent means on.
  final bool? socialPushComments,

  /// Push for follows; absent means on.
  final bool? socialPushFollows,

  /// Push for nudges; absent means on.
  final bool? socialPushNudges,

  /// Push for mentions; absent means on.
  final bool? socialPushMentions,

  /// Push for shares; absent means on.
  final bool? socialPushShares,

  /// Local hour (0-23) for the streak reminder.
  final int? reminderHour,

  /// IANA time zone, written with the push token.
  final String? timezone,

  /// Streak reminder; absent means off.
  final bool? socialPushStreakReminder,

  /// Weekly digest push.
  final bool? socialPushWeeklyDigest,

  /// The weekly streak, for `streakReminder`.
  final int? weekStreak,

  /// Sessions this week.
  final int? weekSessions,

  /// Session goal this week.
  final int? weekGoal,

  /// When this week ends on the user's calendar.
  final DateTime? weekEndsAt,

  /// When the user last trained.
  final DateTime? lastTrainedAt,

  /// Push for challenges.
  final bool? socialPushChallenges,

  /// Come-back reminders; absent means on.
  final bool? pushComeBackReminders,

  /// Meal reminders; absent means off.
  final bool? pushMealReminders,

  /// Consent to the AI coach; `false` once withdrawn.
  final bool? coachConsent,

  /// When coach consent was last given.
  final DateTime? coachConsentAt,
}) {
  /// Creates a [PrivateUserSettings].
  this;

  /// Decodes a Firestore-shaped map as strictly as the Swift decoder:
  /// a missing required field, a wrong type or an unknown enum value
  /// throws. Unknown keys are ignored, and a null reads as absent.
  factory fromFirestore(Map<String, Object?> data) => PrivateUserSettings(
    fcmToken: data[PrivateUserSettingsKeys.fcmToken] as String?,
    socialPushLikes: data[PrivateUserSettingsKeys.socialPushLikes] as bool?,
    socialPushComments:
        data[PrivateUserSettingsKeys.socialPushComments] as bool?,
    socialPushFollows: data[PrivateUserSettingsKeys.socialPushFollows] as bool?,
    socialPushNudges: data[PrivateUserSettingsKeys.socialPushNudges] as bool?,
    socialPushMentions:
        data[PrivateUserSettingsKeys.socialPushMentions] as bool?,
    socialPushShares: data[PrivateUserSettingsKeys.socialPushShares] as bool?,
    reminderHour: data[PrivateUserSettingsKeys.reminderHour] as int?,
    timezone: data[PrivateUserSettingsKeys.timezone] as String?,
    socialPushStreakReminder:
        data[PrivateUserSettingsKeys.socialPushStreakReminder] as bool?,
    socialPushWeeklyDigest:
        data[PrivateUserSettingsKeys.socialPushWeeklyDigest] as bool?,
    weekStreak: data[PrivateUserSettingsKeys.weekStreak] as int?,
    weekSessions: data[PrivateUserSettingsKeys.weekSessions] as int?,
    weekGoal: data[PrivateUserSettingsKeys.weekGoal] as int?,
    weekEndsAt: data[PrivateUserSettingsKeys.weekEndsAt] as DateTime?,
    lastTrainedAt: data[PrivateUserSettingsKeys.lastTrainedAt] as DateTime?,
    socialPushChallenges:
        data[PrivateUserSettingsKeys.socialPushChallenges] as bool?,
    pushComeBackReminders:
        data[PrivateUserSettingsKeys.pushComeBackReminders] as bool?,
    pushMealReminders: data[PrivateUserSettingsKeys.pushMealReminders] as bool?,
    coachConsent: data[PrivateUserSettingsKeys.coachConsent] as bool?,
    coachConsentAt: data[PrivateUserSettingsKeys.coachConsentAt] as DateTime?,
  );

  /// The Firestore-shaped map Swift writes: a null field is left out,
  /// never written as null.
  Map<String, Object?> toFirestore() => {
    PrivateUserSettingsKeys.fcmToken: ?fcmToken,
    PrivateUserSettingsKeys.socialPushLikes: ?socialPushLikes,
    PrivateUserSettingsKeys.socialPushComments: ?socialPushComments,
    PrivateUserSettingsKeys.socialPushFollows: ?socialPushFollows,
    PrivateUserSettingsKeys.socialPushNudges: ?socialPushNudges,
    PrivateUserSettingsKeys.socialPushMentions: ?socialPushMentions,
    PrivateUserSettingsKeys.socialPushShares: ?socialPushShares,
    PrivateUserSettingsKeys.reminderHour: ?reminderHour,
    PrivateUserSettingsKeys.timezone: ?timezone,
    PrivateUserSettingsKeys.socialPushStreakReminder: ?socialPushStreakReminder,
    PrivateUserSettingsKeys.socialPushWeeklyDigest: ?socialPushWeeklyDigest,
    PrivateUserSettingsKeys.weekStreak: ?weekStreak,
    PrivateUserSettingsKeys.weekSessions: ?weekSessions,
    PrivateUserSettingsKeys.weekGoal: ?weekGoal,
    PrivateUserSettingsKeys.weekEndsAt: ?weekEndsAt,
    PrivateUserSettingsKeys.lastTrainedAt: ?lastTrainedAt,
    PrivateUserSettingsKeys.socialPushChallenges: ?socialPushChallenges,
    PrivateUserSettingsKeys.pushComeBackReminders: ?pushComeBackReminders,
    PrivateUserSettingsKeys.pushMealReminders: ?pushMealReminders,
    PrivateUserSettingsKeys.coachConsent: ?coachConsent,
    PrivateUserSettingsKeys.coachConsentAt: ?coachConsentAt,
  };
}
