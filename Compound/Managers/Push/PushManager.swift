//
//  PushManager.swift
//  Compound
//
//  Created by Andrew Coyle on 02/10/2025.
//

import Foundation
import UserNotifications

@Observable
@MainActor
class PushManager {

    let logManager: LogManager?

    var isAuthorised: UNAuthorizationStatus = .notDetermined

    /// Where the last tapped push wants to go, held until someone who can navigate takes it. A tap
    /// that launches the app arrives before any screen is observing, so a broadcast alone was lost.
    private(set) var pendingDeepLink: DeepLink?

    /// Set by `CoreInteractor.logIn` once the sync engines are listening, cleared on sign-out. A
    /// link consumed before then would open a session the managers cannot fetch yet.
    private(set) var isReadyForDeepLinks = false

    /// Stores the destination of a tapped push, parsed by the caller with `DeepLink(pushUserInfo:)`.
    /// A payload with nowhere to go (nil) is ignored and leaves any earlier pending link alone.
    func storePendingDeepLink(_ link: DeepLink?) {
        guard let link else { return }
        pendingDeepLink = link
    }

    /// Hands over the pending link exactly once, and only once signed in.
    func consumePendingDeepLink() -> DeepLink? {
        guard isReadyForDeepLinks, let link = pendingDeepLink else { return nil }
        pendingDeepLink = nil
        return link
    }

    func setReadyForDeepLinks(_ ready: Bool) {
        isReadyForDeepLinks = ready
        if !ready { pendingDeepLink = nil }
    }

    init(logManager: LogManager? = nil) {
        self.logManager = logManager
    }
    
    func checkPushNotificationAuthorisation() async throws -> UNAuthorizationStatus {
        self.isAuthorised = try await LocalNotifications.getNotificationStatus()
        return self.isAuthorised
    }

    func requestAuthorisation() async throws -> Bool {
        let isAuthorised = try await LocalNotifications.requestAuthorization()
        logManager?.addUserProperties(dict: ["push_is_authorised": isAuthorised], isHighPriority: true)
        return isAuthorised
    }

    func canRequestAuthorisation() async -> Bool {
        await LocalNotifications.canRequestAuthorization()
    }
    
    func removeDeliveredNotifications(ids: [String]) {
        LocalNotifications.removeNotifications(ids: ids, pending: false, delivered: true)
    }

    func clearAllDeliveredNotifications() {
        LocalNotifications.removeAllDeliveredNotifications()
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }
    
    // MARK: - Come-back reminders

    /// A day, three days and five days out, rescheduled each time the app signs in or comes to the
    /// front, so they arrive only after that long away.
    static let comeBackReminderIDs = ["come_back_reminder_1", "come_back_reminder_3", "come_back_reminder_5"]

    /// The three come-back reminders, counted from now. Statements, not instructions, and no emoji.
    static func comeBackReminderRequests() -> [UNNotificationRequest] {
        let reminders = [
            (days: 1, title: String(localized: "Keep the Momentum"), body: String(localized: "Your training plan is ready for your next session.")),
            (days: 3, title: String(localized: "Stay Consistent"), body: String(localized: "It's been a few days since you opened Compound. Your plan is ready when you are.")),
            (days: 5, title: String(localized: "Your Progress Is Waiting"), body: String(localized: "Your workouts and history are right where you left them."))
        ]
        return zip(comeBackReminderIDs, reminders).map { id, reminder in
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(reminder.days) * 86_400, repeats: false)
            return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        }
    }

    /// Every pending request this app still means to deliver. Anything else pending was left by an
    /// older version (its come-back reminders had random ids) and is withdrawn.
    /// ponytail: a new local notification must add its id here, or the next launch withdraws it.
    static var knownPendingIDs: Set<String> {
        Set(comeBackReminderIDs + mealReminderIDs + [RestOverNotification.id])
    }

    /// Schedules the come-back reminders afresh when they are on, and only withdraws them when off.
    func scheduleComeBackReminders(isEnabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let stale = pending.filter { !Self.knownPendingIDs.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: stale + Self.comeBackReminderIDs)
        guard isEnabled else { return }
        do {
            // Scheduling without permission throws UNErrorDomain 2003 and logged a failure on every launch.
            guard [.authorized, .provisional, .ephemeral].contains(try await checkPushNotificationAuthorisation()) else { return }
            for request in Self.comeBackReminderRequests() {
                try await center.add(request)
            }
            logManager?.trackEvent(event: Event.weekScheduledSuccess)
        } catch {
            logManager?.trackEvent(event: Event.weekScheduledFail(error: error))
        }
    }

    func schedulePushNotification(delegate: PushNotificationDelegate) async throws {
        // Onboarding no longer asks for notifications, so the first feature that needs one does.
        // Today that is the rest timer. iOS shows the alert once; after that this is a no-op.
        if await canRequestAuthorisation() {
            _ = try? await requestAuthorisation()
        }
        let request = UNNotificationRequest(identifier: delegate.identifier, content: delegate.content, trigger: delegate.trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Meal reminders

    static let mealReminderIDs = ["meal_reminder_breakfast", "meal_reminder_lunch", "meal_reminder_dinner"]

    /// Breakfast, lunch and dinner, daily. Passive: they wait in Notification Center rather than
    /// lighting the screen.
    static func mealReminderRequests() -> [UNNotificationRequest] {
        let reminders = [
            (title: String(localized: "Breakfast"), body: String(localized: "A reminder to log your breakfast."), hour: 8, minute: 0),
            (title: String(localized: "Lunch"), body: String(localized: "A reminder to log your lunch."), hour: 12, minute: 30),
            (title: String(localized: "Dinner"), body: String(localized: "A reminder to log your dinner."), hour: 18, minute: 30)
        ]
        return zip(mealReminderIDs, reminders).map { id, reminder in
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.interruptionLevel = .passive
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: reminder.hour, minute: reminder.minute), repeats: true)
            return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        }
    }

    /// Schedules the meal reminders when on and withdraws them when off. Off is the default, so a
    /// device that had them scheduled by an older version, unasked, loses them here.
    func setMealReminders(isEnabled: Bool) async throws {
        cancelMealReminderNotifications()
        guard isEnabled else { return }
        for request in Self.mealReminderRequests() {
            try await UNUserNotificationCenter.current().add(request)
        }
        logManager?.trackEvent(event: Event.mealRemindersScheduled)
    }

    func cancelMealReminderNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Self.mealReminderIDs)
    }

    // MARK: - Foreground presentation

    /// Types the Cloud Functions send for social activity (`data.type` in `functions/lib.js`).
    nonisolated static let socialPushTypes: Set<String> = [
        "like", "comment", "mention", "follow", "followAccepted", "follow_request", "nudge", "share", "challenge_complete"
    ]

    /// How a notification shows while the app is in front. Social activity already appears in the
    /// app (the in-app banner and the bell's badge), so it goes quietly to Notification Center. The
    /// rest-over alert is silent here because the tracker plays its own sound and haptic.
    nonisolated static func foregroundPresentation(identifier: String, type: String?) -> UNNotificationPresentationOptions {
        if identifier == RestOverNotification.id { return [] }
        if let type, socialPushTypes.contains(type) { return [.list, .badge] }
        return [.banner, .sound, .badge]
    }

    enum Event: LoggableEvent {
        case weekScheduledSuccess
        case weekScheduledFail(error: Error)
        case mealRemindersScheduled

        var eventName: String {
            switch self {
            case .weekScheduledSuccess:  return "PushMan_WeekScheduled_Success"
            case .weekScheduledFail:     return "PushMan_WeekScheduled_Fail"
            case .mealRemindersScheduled: return "PushMan_MealReminders_Scheduled"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .weekScheduledFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .weekScheduledFail:
                return .severe
            default:
                return .analytic

            }
        }
    }
}

extension CoreInteractor {
    
    // MARK: PushManager
    
    var isAuthorised: UNAuthorizationStatus {
        pushManager.isAuthorised
    }
    
    func checkPushNotificationAuthorisation() async throws -> UNAuthorizationStatus {
        try await pushManager.checkPushNotificationAuthorisation()
    }
    
    func schedulePushNotification(delegate: PushNotificationDelegate) async throws {
        try await pushManager.schedulePushNotification(delegate: delegate)
    }

    func requestPushAuthorisation() async throws -> Bool {
        try await pushManager.requestAuthorisation()
    }
    
    func canRequestNotificationAuthorisation() async -> Bool {
        await pushManager.canRequestAuthorisation()
    }
    
    func removeDeliveredNotifications(ids: [String]) {
        pushManager.removeDeliveredNotifications(ids: ids)
    }

    func clearAllDeliveredNotifications() {
        pushManager.clearAllDeliveredNotifications()
    }

    /// Brings this device's local reminders into line with the private settings: come-back
    /// reminders rescheduled when on, meal reminders scheduled when on and withdrawn when off.
    /// Called once signed in, when the settings document is cached, and on each return to the app.
    func applyLocalReminderSettings() async {
        let settings = privateUserSettings
        await pushManager.scheduleComeBackReminders(isEnabled: settings.isComeBackRemindersEnabled)
        try? await pushManager.setMealReminders(isEnabled: settings.isMealRemindersEnabled)
    }

    /// Nutrition calls this on its first visit. Meal reminders are off unless chosen, so it only
    /// keeps the device in step with the switch; the offer is `ReminderOfferFlow`'s.
    func scheduleMealReminderNotifications() async throws {
        try await pushManager.setMealReminders(isEnabled: privateUserSettings.isMealRemindersEnabled)
    }

    func setComeBackReminders(isEnabled: Bool) async throws {
        try await updatePrivateUserSettings { $0.pushComeBackReminders = isEnabled }
        await pushManager.scheduleComeBackReminders(isEnabled: isEnabled)
    }

    /// The switch is saved even when scheduling fails (no permission yet): it takes effect at the
    /// next sign-in once notifications are allowed.
    func setMealReminders(isEnabled: Bool) async throws {
        try await updatePrivateUserSettings { $0.pushMealReminders = isEnabled }
        try? await pushManager.setMealReminders(isEnabled: isEnabled)
    }

    /// Sent by the server (`streakReminder` in `functions/`), so only the setting changes here.
    func setStreakReminder(isEnabled: Bool) async throws {
        try await updatePrivateUserSettings { $0.socialPushStreakReminder = isEnabled }
    }

    func consumePendingDeepLink() -> DeepLink? {
        pushManager.consumePendingDeepLink()
    }

    /// Called at the end of `logIn`: marks deep links routable and nudges a tab bar that is already
    /// on screen to take one waiting from a cold-start tap.
    func routePendingDeepLinkAfterLogIn() {
        pushManager.setReadyForDeepLinks(true)
        NotificationCenter.default.post(name: .pushNotification, object: nil)
    }

}

/// The alert text `functions/lib.js` sends as `loc-key` and `title-loc-key`. iOS looks each key up
/// in this app's string catalog when the push arrives, so spelling them here is what puts them in
/// the catalog to be translated. The social ones the Notifications screen already shows ("%@ liked
/// your workout") are not repeated. Arguments are strings, as loc-args are.
enum RemotePushCopy {
    static func catalogEntries(_ first: String, _ second: String) -> [String] {
        [
            String(localized: "\(first) replied to your comment: \"\(second)\""),
            String(localized: "\(first) wants to follow you"),
            String(localized: "Streak at Risk"),
            String(localized: "Your \(first)-day streak ends at midnight."),
            String(localized: "Your Week"),
            String(localized: "Workouts this week: you \(first), your circle \(second).")
        ]
    }
}
