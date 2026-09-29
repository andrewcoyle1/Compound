//
//  RestOverNotifying.swift
//  DialedIn
//
//  The local notification that says a rest is over. `HKWorkoutManager` owns the rest timer, so it
//  owns this too: every start, +15s, skip, finish and discard moves or withdraws it from there.
//

import Foundation
import UserNotifications

@MainActor
protocol RestOverNotifying: AnyObject {
    /// Schedules, or moves, the one rest-over notification. `body` is the "Next: …" line.
    func scheduleRestOverNotification(at date: Date, body: String?, sound: Bool) async
    /// Withdraws it if it has not been delivered yet.
    func cancelRestOverNotification()
}

enum RestOverNotification {
    /// One pending request at a time: scheduling again under the same id replaces it. Read by the
    /// app delegate, which keeps it quiet while the app is in front.
    static let id = "workout-rest-timer"
}

extension PushManager: RestOverNotifying {

    func scheduleRestOverNotification(at date: Date, body: String?, sound: Bool) async {
        let delegate = PushNotificationDelegate(
            identifier: RestOverNotification.id,
            title: String(localized: "Rest Complete"),
            subtitle: body ?? "",
            triggerDate: date,
            sound: sound,
            badge: nil,
            // About something happening now, so it breaks through a Focus. With "Play Sound" off it
            // is still delivered, as a silent banner, so a locked phone shows the rest has ended.
            interruptionLevel: .timeSensitive
        )
        // Through `schedulePushNotification`, which asks for permission the first time. A failure
        // is dropped: the rest runs out whether or not anything announces it.
        try? await schedulePushNotification(delegate: delegate)
    }

    func cancelRestOverNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [RestOverNotification.id])
    }
}
