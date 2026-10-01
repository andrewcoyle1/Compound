//
//  RestOverNotifying.swift
//  Compound
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

/// Who says a rest is over, decided when it runs out. Foreground and background are the same case:
/// what matters is only whether the app's timer fired on time. With an Apple Health workout
/// session running, iOS keeps the app running behind a locked screen, so it does; without one
/// (Health access declined, or the session failed to start) the app is suspended, its timer fires
/// late when it is next woken, and the notification scheduled at the start of the rest has already
/// spoken. The notification is scheduled for every rest either way.
enum RestOverAlert: Equatable {
    /// The Live Activity alerts; the stand-in notification is withdrawn.
    case liveActivity
    /// The Live Activity is only cleared, since its alert cannot be silent and "Play Sound" is off;
    /// the notification is withdrawn all the same.
    case clearLiveActivity
    /// The notification is the alert: no Live Activity, or the app got there too late.
    case notification

    /// How long after the end of a rest the stand-in notification waits for the app to withdraw
    /// it and alert through the Live Activity instead.
    static let standInDelay: TimeInterval = 2

    /// `lateBy` is how long after the rest's end the app's timer fired.
    static func channel(showingLiveActivity: Bool, lateBy: TimeInterval, sound: Bool) -> RestOverAlert {
        guard showingLiveActivity, lateBy < standInDelay else { return .notification }
        return sound ? .liveActivity : .clearLiveActivity
    }

    /// When the notification is due: on the second with no Live Activity, where it is the alert;
    /// `standInDelay` late with one, where it only stands in for a suspended app.
    static func notificationDate(restEnd: Date, showingLiveActivity: Bool) -> Date {
        showingLiveActivity ? restEnd.addingTimeInterval(standInDelay) : restEnd
    }
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
