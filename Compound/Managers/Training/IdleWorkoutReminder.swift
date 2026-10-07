//
//  IdleWorkoutReminder.swift
//  Compound
//
//  "Still training?": a workout left running long after its last set pollutes its duration, the
//  calories sent to Apple Health and the battery (edges.md §4, "4-hour workout"). A local
//  notification an hour after the last logged set, moved by every log and withdrawn on finish or
//  discard; the tracker asks again when it next comes to the front.
//

import Foundation
import UserNotifications

enum IdleWorkoutReminder {

    /// How long after the last logged set a workout counts as forgotten.
    static let threshold: TimeInterval = 60 * 60

    /// One pending request at a time: scheduling again under the same id replaces it.
    static let notificationId = "workout-idle-reminder"

    static func isIdle(lastActivity: Date, now: Date, threshold: TimeInterval = threshold) -> Bool {
        now.timeIntervalSince(lastActivity) >= threshold
    }

    /// Schedules, or moves, the reminder to an hour after `lastLog`. Permission is not asked for
    /// here: the rest-over notification asks with the first rest, and without it nothing shows.
    static func schedule(after lastLog: Date, now: Date = Date()) {
        let interval = lastLog.addingTimeInterval(threshold).timeIntervalSince(now)
        guard interval > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Still training?")
        content.body = String(localized: "No set logged in the last hour.")
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        // A failure is dropped: the tracker still asks when it next comes to the front.
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
        center.removeDeliveredNotifications(withIdentifiers: [notificationId])
    }
}
