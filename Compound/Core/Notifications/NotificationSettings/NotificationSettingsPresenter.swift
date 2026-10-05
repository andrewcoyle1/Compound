//
//  NotificationSettingsPresenter.swift
//  Compound
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

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
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
            interactor.trackEvent(event: Event.checkPermissionsFail(error: error))
            router.showAlert(title: String(localized: "Unable to Check Notification Permission"), error: error)
        }
    }

    /// Re-read on return to the app, since the Settings app is where a denial is undone.
    func onSceneBecameActive() {
        Task { await checkPermissions() }
    }

    func onRequestNotificationsPressed() {
        interactor.trackEvent(event: Event.requestPermissionStart)
        Task {
            do {
                let granted = try await interactor.requestPushAuthorisation()
                interactor.trackEvent(event: Event.requestPermissionSuccess(granted: granted))
                // The answer changes which rows show, so read the status back straight away.
                await checkPermissions()
            } catch {
                // A permission request the user asked for either works or says why.
                interactor.trackEvent(event: Event.requestPermissionFail(error: error))
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
        save(.socialPushToggled(type: type, isEnabled: isEnabled)) {
            try await self.interactor.updateSocialNotificationPreferences(type: type, isEnabled: isEnabled)
        }
    }

    // MARK: - Reminders

    /// The streak reminder, its hour, and the Sunday digest. Like the Social switches, each writes
    /// the moment it changes and reads back from the private settings document. The streak
    /// reminder is off until chosen; `ReminderOfferFlow` offers it at a two-week streak.
    var isStreakReminderEnabled: Bool {
        get { interactor.privateUserSettings.isStreakReminderEnabled }
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
        save(event) { try await self.interactor.updatePrivateUserSettings(change) }
    }

    /// Come-back reminders are on unless turned off; meal reminders off unless turned on. Both are
    /// scheduled on this device, so the switch also schedules or withdraws them.
    var isComeBackRemindersEnabled: Bool {
        get { interactor.privateUserSettings.isComeBackRemindersEnabled }
        set { save(.comeBackReminders(isEnabled: newValue)) { try await self.interactor.setComeBackReminders(isEnabled: newValue) } }
    }

    var isMealRemindersEnabled: Bool {
        get { interactor.privateUserSettings.isMealRemindersEnabled }
        set { save(.mealReminders(isEnabled: newValue)) { try await self.interactor.setMealReminders(isEnabled: newValue) } }
    }

    private func save(_ event: Event, _ write: @escaping () async throws -> Void) {
        interactor.trackEvent(event: event)
        let setting = event.eventName
        interactor.trackEvent(event: Event.saveStart(setting: setting))
        Task {
            do {
                try await write()
                interactor.trackEvent(event: Event.saveSuccess(setting: setting))
            } catch {
                interactor.trackEvent(event: Event.saveFail(setting: setting, error: error))
                router.showAlert(title: String(localized: "Unable to Save Setting"), error: error)
            }
        }
    }

    /// The switch events keep the `NotificationsView_` names they had when the switches lived on
    /// that screen, so the funnels built on them carry on.
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case checkPermissionsFail(error: Error)
        case requestPermissionStart
        case requestPermissionSuccess(granted: Bool)
        case requestPermissionFail(error: Error)
        case saveStart(setting: String)
        case saveSuccess(setting: String)
        case saveFail(setting: String, error: Error)
        case socialPushToggled(type: ActivityNotificationModel.ActivityType, isEnabled: Bool)
        case streakReminder(isEnabled: Bool)
        case reminderHour(hour: Int)
        case weeklyDigest(isEnabled: Bool)
        case comeBackReminders(isEnabled: Bool)
        case mealReminders(isEnabled: Bool)

        var eventName: String {
            switch self {
            case .onAppear: return "NotificationSettingsView_Appear"
            case .onDisappear: return "NotificationSettingsView_Disappear"
            case .checkPermissionsFail: return "NotificationSettingsView_CheckPermissions_Fail"
            case .requestPermissionStart: return "NotificationSettingsView_RequestPermission_Start"
            case .requestPermissionSuccess: return "NotificationSettingsView_RequestPermission_Success"
            case .requestPermissionFail: return "NotificationSettingsView_RequestPermission_Fail"
            case .saveStart: return "NotificationSettingsView_SaveSetting_Start"
            case .saveSuccess: return "NotificationSettingsView_SaveSetting_Success"
            case .saveFail: return "NotificationSettingsView_SaveSetting_Fail"
            case .socialPushToggled: return "NotificationsView_SocialPush_Toggle"
            case .streakReminder: return "NotificationsView_StreakReminder_Toggle"
            case .reminderHour: return "NotificationsView_ReminderHour_Changed"
            case .weeklyDigest: return "NotificationsView_WeeklyDigest_Toggle"
            case .comeBackReminders: return "NotificationSettingsView_ComeBackReminders_Toggle"
            case .mealReminders: return "NotificationSettingsView_MealReminders_Toggle"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear, .onDisappear, .requestPermissionStart: return nil
            case .checkPermissionsFail(let error), .requestPermissionFail(let error): return error.eventParameters
            case .requestPermissionSuccess(let granted): return ["granted": granted]
            case .saveStart(let setting), .saveSuccess(let setting): return ["setting": setting]
            case .saveFail(let setting, let error): return error.eventParameters.merging(["setting": setting]) { current, _ in current }
            case .socialPushToggled(let type, let isEnabled): return ["type": type.rawValue, "is_enabled": isEnabled]
            case .streakReminder(let isEnabled), .weeklyDigest(let isEnabled),
                 .comeBackReminders(let isEnabled), .mealReminders(let isEnabled):
                return ["is_enabled": isEnabled]
            case .reminderHour(let hour): return ["hour": hour]
            }
        }

        var type: LogType {
            switch self {
            case .checkPermissionsFail, .requestPermissionFail, .saveFail: return .severe
            default: return .analytic
            }
        }
    }
}
