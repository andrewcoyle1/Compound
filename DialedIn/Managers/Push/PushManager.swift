//
//  PushManager.swift
//  DialedIn
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
    
    func schedulePushNotificationsForNextWeek() {
        LocalNotifications.removeAllPendingNotifications()
        LocalNotifications.removeAllDeliveredNotifications()
        
        Task {
            do {
                // Scheduling without permission throws UNErrorDomain 2003 and logged a failure on every launch.
                guard [.authorized, .provisional, .ephemeral].contains(try await checkPushNotificationAuthorisation()) else { return }

                // Tomorrow
                try await scheduleNotification(
                    title: "Keep up the momentum!",
                    subtitle: "Your next workout is just a day away. Ready to crush it tomorrow?",
                    triggerDate: Date().addingTimeInterval(days: 1)
                )

                // In 3 days
                try await scheduleNotification(
                    title: "Stay Consistent",
                    subtitle: "It's been a few days since your last session. Let's get moving!",
                    triggerDate: Date().addingTimeInterval(days: 3)
                )
                
                // In 5 days
                try await scheduleNotification(
                    title: "Don't Lose Your Streak!",
                    subtitle: "Come back for a workout and keep your progress going strong.",
                    triggerDate: Date().addingTimeInterval(days: 5)
                )
                                
                logManager?.trackEvent(event: Event.weekScheduledSuccess)
            } catch {
                logManager?.trackEvent(event: Event.weekScheduledFail(error: error))
            }
        }
    }
        
    func schedulePushNotification(delegate: PushNotificationDelegate) async throws {
        let content = AnyNotificationContent(id: delegate.identifier, title: delegate.title, body: delegate.subtitle, sound: delegate.sound, badge: delegate.badge)
        let trigger = NotificationTriggerOption.date(date: delegate.triggerDate, repeats: delegate.repeats)
        try await LocalNotifications.scheduleNotification(content: content, trigger: trigger)
    }
    
    private func scheduleNotification(title: String, subtitle: String, triggerDate: Date) async throws {
        let content = AnyNotificationContent(title: title, body: subtitle)
        let trigger = NotificationTriggerOption.date(date: triggerDate, repeats: false)
        try await LocalNotifications.scheduleNotification(content: content, trigger: trigger)
    }

    static let mealReminderIDs = ["meal_reminder_breakfast", "meal_reminder_lunch", "meal_reminder_dinner"]

    func scheduleMealReminderNotifications() async throws {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Self.mealReminderIDs)

        // swiftlint:disable:next large_tuple
        let reminders: [(id: String, title: String, body: String, hour: Int, minute: Int)] = [
            ("meal_reminder_breakfast", "Time for Breakfast 🍳", "Don't forget to log your breakfast.", 8, 0),
            ("meal_reminder_lunch", "Lunch Time 🥗", "Log your lunch to stay on track.", 12, 30),
            ("meal_reminder_dinner", "Dinner Reminder 🍽️", "Time to log your dinner.", 18, 30)
        ]

        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default

            var components = DateComponents()
            components.hour = reminder.hour
            components.minute = reminder.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
            try await UNUserNotificationCenter.current().add(request)
        }
        logManager?.trackEvent(event: Event.mealRemindersScheduled)
    }

    func cancelMealReminderNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Self.mealReminderIDs)
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
    
    func schedulePushNotificationsForNextWeek() {
        pushManager.schedulePushNotificationsForNextWeek()
    }
    
    func removeDeliveredNotifications(ids: [String]) {
        pushManager.removeDeliveredNotifications(ids: ids)
    }

    func clearAllDeliveredNotifications() {
        pushManager.clearAllDeliveredNotifications()
    }

    func scheduleMealReminderNotifications() async throws {
        try await pushManager.scheduleMealReminderNotifications()
    }

    func cancelMealReminderNotifications() {
        pushManager.cancelMealReminderNotifications()
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
