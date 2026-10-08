//
//  IdleWorkoutReminderTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// When a workout counts as forgotten: an hour after its last logged set.
struct IdleWorkoutReminderTests {

    private let lastSet = Date(timeIntervalSince1970: 1_000_000)

    @Test("Test A Workout Is Idle From An Hour After The Last Set", arguments: [3_540.0, 3_600, 14_400])
    func testIdleFromAnHour(after seconds: TimeInterval) {
        let idle = IdleWorkoutReminder.isIdle(lastActivity: lastSet, now: lastSet.addingTimeInterval(seconds))
        #expect(idle == (seconds >= 3_600))
    }

    /// A clock that went backwards (a time-zone or manual change) is not a forgotten workout.
    @Test("Test A Last Set In The Future Is Not Idle")
    func testFutureIsNotIdle() {
        #expect(!IdleWorkoutReminder.isIdle(lastActivity: lastSet, now: lastSet.addingTimeInterval(-3_600)))
    }

    @Test("Test The Threshold Can Be Shortened")
    func testCustomThreshold() {
        #expect(IdleWorkoutReminder.isIdle(lastActivity: lastSet, now: lastSet.addingTimeInterval(45 * 60), threshold: 45 * 60))
    }
}
