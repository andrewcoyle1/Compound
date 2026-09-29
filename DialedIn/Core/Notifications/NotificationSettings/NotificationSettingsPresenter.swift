//
//  NotificationSettingsPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 29/09/2026.
//

import SwiftUI
import UserNotifications

@Observable
@MainActor
class NotificationSettingsPresenter {
    private let interactor: NotificationSettingsInteractor
    private let router: NotificationSettingsRouter

    init(interactor: NotificationSettingsInteractor, router: NotificationSettingsRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    // MARK: - Permission

    /// What stands between the switches and a delivered push, if anything.
    enum PermissionPrompt {
        /// Never asked: explain and offer to ask.
        case askFirst
        /// Refused: only the Settings app can turn them back on.
        case denied
    }

    var authorizationStatus: UNAuthorizationStatus {
        interactor.isAuthorised
    }

    var permissionPrompt: PermissionPrompt? {
        switch authorizationStatus {
        case .notDetermined: return .askFirst
        case .denied: return .denied
        default: return nil
        }
    }

    /// The switches change what the server sends, which arrives only once iOS allows it, so they
    /// are usable only then rather than flipping with nothing to show for it.
    var canChangeSwitches: Bool {
        permissionPrompt == nil
    }

    func checkPermissions() async {
        do {
            _ = try await interactor.checkPushNotificationAuthorisation()
        } catch {
            router.showAlert(title: String(localized: "Unable to Check Notification Permission"), error: error)
        }
    }

    /// Re-read on return to the app, since the Settings app is where a denial is undone.
    func onSceneBecameActive() {
        Task { await checkPermissions() }
    }

    func onRequestNotificationsPressed() {
        Task {
            do {
                _ = try await interactor.requestPushAuthorisation()
                // The answer changes which rows show, so read the status back straight away.
                await checkPermissions()
            } catch {
                // A permission request the user asked for either works or says why.
                router.showAlert(title: String(localized: "Unable to Enable Notifications"), error: error)
            }
        }
    }

    func onOpenSettingsPressed() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Social

    /// Each writes the moment it flips, like the Account privacy switch, and reads back from the
    /// private settings document, so a failed write snaps the switch back once the alert shows.
    var isLikesPushEnabled: Bool {
        get { isSocialPushEnabled(.like) }
        set { onSocialPushToggled(.like, isEnabled: newValue) }
    }

    var isCommentsPushEnabled: Bool {
        get { isSocialPushEnabled(.comment) }
        set { onSocialPushToggled(.comment, isEnabled: newValue) }
    }

    var isMentionsPushEnabled: Bool {
        get { isSocialPushEnabled(.mention) }
        set { onSocialPushToggled(.mention, isEnabled: newValue) }
    }

    var isFollowsPushEnabled: Bool {
        get { isSocialPushEnabled(.follow) }
        set { onSocialPushToggled(.follow, isEnabled: newValue) }
    }

    var isNudgesPushEnabled: Bool {
        get { isSocialPushEnabled(.nudge) }
        set { onSocialPushToggled(.nudge, isEnabled: newValue) }
    }

    var isSharesPushEnabled: Bool {
        get { isSocialPushEnabled(.share) }
        set { onSocialPushToggled(.share, isEnabled: newValue) }
    }

    var isChallengesPushEnabled: Bool {
        get { isSocialPushEnabled(.challengeComplete) }
        set { onSocialPushToggled(.challengeComplete, isEnabled: newValue) }
    }

    private func isSocialPushEnabled(_ type: ActivityNotificationModel.ActivityType) -> Bool {
        interactor.privateUserSettings.isSocialPushEnabled(for: type)
    }

    private func onSocialPushToggled(_ type: ActivityNotificationModel.ActivityType, isEnabled: Bool) {
        interactor.trackEvent(event: Event.socialPushToggled(type: type, isEnabled: isEnabled))
        Task {
            do {
                try await interactor.updateSocialNotificationPreferences(type: type, isEnabled: isEnabled)
            } catch {
                router.showAlert(title: String(localized: "Unable to Save Setting"), error: error)
            }
        }
    }

    // MARK: - Reminders

    /// The streak reminder, its hour, and the Sunday digest. Like the Social switches, each writes
    /// the moment it changes and reads back from the private settings document.
    var isStreakReminderEnabled: Bool {
        get { interactor.privateUserSettings.socialPushStreakReminder ?? true }
        set { updateScheduledPush(.streakReminder(isEnabled: newValue)) { $0.socialPushStreakReminder = newValue } }
    }

    var streakReminderHour: Int {
        get { interactor.privateUserSettings.reminderHour ?? PrivateUserSettings.defaultReminderHour }
        set { updateScheduledPush(.reminderHour(hour: newValue)) { $0.reminderHour = newValue } }
    }

    var isWeeklyDigestEnabled: Bool {
        get { interactor.privateUserSettings.socialPushWeeklyDigest ?? true }
        set { updateScheduledPush(.weeklyDigest(isEnabled: newValue)) { $0.socialPushWeeklyDigest = newValue } }
    }

    private func updateScheduledPush(_ event: Event, _ change: @escaping (inout PrivateUserSettings) -> Void) {
        interactor.trackEvent(event: event)
        Task {
            do {
                try await interactor.updatePrivateUserSettings(change)
            } catch {
                router.showAlert(title: String(localized: "Unable to Save Setting"), error: error)
            }
        }
    }

    /// The switch events keep the `NotificationsView_` names they had when the switches lived on
    /// that screen, so the funnels built on them carry on.
    enum Event: LoggableEvent {
        case onAppear
        case socialPushToggled(type: ActivityNotificationModel.ActivityType, isEnabled: Bool)
        case streakReminder(isEnabled: Bool)
        case reminderHour(hour: Int)
        case weeklyDigest(isEnabled: Bool)

        var eventName: String {
            switch self {
            case .onAppear: return "NotificationSettingsView_Appear"
            case .socialPushToggled: return "NotificationsView_SocialPush_Toggle"
            case .streakReminder: return "NotificationsView_StreakReminder_Toggle"
            case .reminderHour: return "NotificationsView_ReminderHour_Changed"
            case .weeklyDigest: return "NotificationsView_WeeklyDigest_Toggle"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear: return nil
            case .socialPushToggled(let type, let isEnabled): return ["type": type.rawValue, "is_enabled": isEnabled]
            case .streakReminder(let isEnabled), .weeklyDigest(let isEnabled): return ["is_enabled": isEnabled]
            case .reminderHour(let hour): return ["hour": hour]
            }
        }

        var type: LogType { .analytic }
    }
}
