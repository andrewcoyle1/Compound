//
//  PrivateUserSettings.swift
//  DialedIn
//

import Foundation

/// `users/{uid}/private/settings`: the fields only the owner may read. The public user document is
/// readable by every signed-in user, so the push token and push opt-outs live here instead. The
/// key names are the contract with `pushRecipientSettings` in `functions/lib.js`.
struct PrivateUserSettings: DataSyncModelProtocol, Equatable {

    static let documentId = "settings"

    /// Not stored: the document id is fixed, so the document holds only the fields below.
    var id: String = PrivateUserSettings.documentId
    var fcmToken: String?
    var socialPushLikes: Bool?
    var socialPushComments: Bool?
    var socialPushFollows: Bool?
    var socialPushNudges: Bool?
    var socialPushMentions: Bool?
    var socialPushShares: Bool?
    // MARK: - ScheduledPush
    /// Local hour (0-23) for the streak reminder; nil means `defaultReminderHour`.
    var reminderHour: Int?
    /// IANA identifier, written with the push token, so the scheduled pushes know the user's clock.
    var timezone: String?
    var socialPushStreakReminder: Bool?
    var socialPushWeeklyDigest: Bool?
    // MARK: - Challenges
    var socialPushChallenges: Bool?

    enum CodingKeys: String, CodingKey {
        case fcmToken = "fcm_token"
        case socialPushLikes = "social_push_likes"
        case socialPushComments = "social_push_comments"
        case socialPushFollows = "social_push_follows"
        case socialPushNudges = "social_push_nudges"
        case socialPushMentions = "social_push_mentions"
        case socialPushShares = "social_push_shares"
        // MARK: - ScheduledPush
        case reminderHour = "reminder_hour"
        case timezone
        case socialPushStreakReminder = "social_push_streak_reminder"
        case socialPushWeeklyDigest = "social_push_weekly_digest"
        // MARK: - Challenges
        case socialPushChallenges = "social_push_challenges"
    }

    var eventParameters: [String: Any] {
        ["user_has_fcm_token": (fcmToken?.count ?? 0) > 0]
    }

    /// The field that opts out of pushes for one kind of social activity. Must match
    /// `SOCIAL_PUSH_PREFERENCE_KEYS` in `functions/lib.js`.
    static func socialPushKey(for type: ActivityNotificationModel.ActivityType) -> CodingKeys {
        switch type {
        case .like: return .socialPushLikes
        case .comment: return .socialPushComments
        case .follow, .followAccepted: return .socialPushFollows
        case .nudge: return .socialPushNudges
        case .mention: return .socialPushMentions
        case .share: return .socialPushShares
        case .challengeComplete: return .socialPushChallenges
        }
    }

    private static func keyPath(for type: ActivityNotificationModel.ActivityType) -> WritableKeyPath<Self, Bool?> {
        switch type {
        case .like: \.socialPushLikes
        case .comment: \.socialPushComments
        case .follow, .followAccepted: \.socialPushFollows
        case .nudge: \.socialPushNudges
        case .mention: \.socialPushMentions
        case .share: \.socialPushShares
        case .challengeComplete: \.socialPushChallenges
        }
    }

    /// On unless the user has switched it off.
    func isSocialPushEnabled(for type: ActivityNotificationModel.ActivityType) -> Bool {
        self[keyPath: Self.keyPath(for: type)] ?? true
    }

    func settingSocialPush(_ type: ActivityNotificationModel.ActivityType, isEnabled: Bool) -> Self {
        var copy = self
        copy[keyPath: Self.keyPath(for: type)] = isEnabled
        return copy
    }
}

// MARK: - ScheduledPush

extension PrivateUserSettings {
    /// Must match `DEFAULT_REMINDER_HOUR` in `functions/lib.js`.
    static let defaultReminderHour = 19
}
