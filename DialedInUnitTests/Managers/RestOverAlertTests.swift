//
//  RestOverAlertTests.swift
//  DialedInUnitTests
//
//  Who says a rest is over. With an Apple Health workout session the app keeps running behind a
//  locked screen, its timer fires on time, and the Live Activity alerts; without one it is
//  suspended, the timer fires late, and the stand-in notification has already spoken.
//

import Testing
import Foundation
@testable import DialedIn

struct RestOverAlertTests {

    private let end = Date(timeIntervalSince1970: 1_772_000_000)

    /// On time, foreground or background alike: the activity alerts and the notification goes.
    @Test("Test On Time With A Live Activity The Activity Alerts", arguments: [0.0, 0.1, 1.9])
    func testOnTimeWithALiveActivityTheActivityAlerts(lateBy: TimeInterval) {
        #expect(RestOverAlert.channel(showingLiveActivity: true, lateBy: lateBy, sound: true) == .liveActivity)
    }

    /// A suspended app woken after the stand-in was due: the notification has said it.
    @Test("Test Late With A Live Activity The Notification Has Already Alerted", arguments: [2.0, 30.0])
    func testLateWithALiveActivityTheNotificationHasAlreadyAlerted(lateBy: TimeInterval) {
        #expect(RestOverAlert.channel(showingLiveActivity: true, lateBy: lateBy, sound: true) == .notification)
    }

    @Test("Test Without A Live Activity The Notification Is The Alert")
    func testWithoutALiveActivityTheNotificationIsTheAlert() {
        #expect(RestOverAlert.channel(showingLiveActivity: false, lateBy: 0, sound: true) == .notification)
    }

    @Test("Test With Sound Off The Activity Is Only Cleared")
    func testWithSoundOffTheActivityIsOnlyCleared() {
        #expect(RestOverAlert.channel(showingLiveActivity: true, lateBy: 0, sound: false) == .clearLiveActivity)
    }

    /// The stand-in stays for everyone with a Live Activity, two seconds after the end, so a
    /// phone without Apple Health access (or whose session failed to start) is still told.
    @Test("Test The Stand-In Notification Is Due Two Seconds After The End With A Live Activity")
    func testTheStandInNotificationIsDueTwoSecondsAfterTheEnd() {
        #expect(RestOverAlert.notificationDate(restEnd: end, showingLiveActivity: true) == end.addingTimeInterval(2))
        #expect(RestOverAlert.notificationDate(restEnd: end, showingLiveActivity: false) == end)
    }
}
