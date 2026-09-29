//
//  HKWorkoutManagerRestAlertTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

#if canImport(HealthKit) && !targetEnvironment(macCatalyst)

@MainActor
private struct RestAlertRig {
    let manager: HKWorkoutManager
    let activity: LiveActivityUpdaterSpy
    let notifier: RestOverNotifierSpy
}

/// The rest-over alert, which `HKWorkoutManager` owns along with the rest timer: the Live
/// Activity alerts when there is one, and the notification stands in when there is not.
///
/// Nested under `WorkoutRestSharedStateTests` because a rest writes its end time to the app group
/// the other rest suites read.
extension WorkoutRestSharedStateTests {

@MainActor
struct HKWorkoutManagerRestAlertTests {

    private static let briefRest: TimeInterval = 0.05

    private func makeRig(showingLiveActivity: Bool) -> RestAlertRig {
        SharedWorkoutStorage.clearRestEndTime()
        let activity = LiveActivityUpdaterSpy()
        activity.isShowingLiveActivity = showingLiveActivity
        let notifier = RestOverNotifierSpy()
        let manager = HKWorkoutManager(logger: LogManager(), liveActivityUpdater: activity, restOverNotifier: notifier)
        return RestAlertRig(manager: manager, activity: activity, notifier: notifier)
    }

    private let session = WorkoutSessionModel(
        id: "session-1",
        authorId: "author-1",
        name: "Upper",
        dateCreated: Date(timeIntervalSince1970: 1_772_000_000),
        exercises: []
    )

    private func scheduledDate(_ call: RestOverNotifierSpy.Call?) -> Date? {
        guard case let .schedule(date, _, _) = call else { return nil }
        return date
    }

    // MARK: - Scheduling

    /// With Live Activities off the notification is the alert, due the moment the rest ends and
    /// saying what comes next.
    @Test("Test Without A Live Activity The Notification Is Due At The End Of The Rest")
    func testWithoutALiveActivityTheNotificationIsDueAtTheEndOfTheRest() async throws {
        let rig = makeRig(showingLiveActivity: false)

        rig.manager.startRest(durationSeconds: 90, session: session, alertSound: false)

        #expect(await TestManagers.eventually { rig.notifier.calls.count == 1 })
        let end = try #require(rig.manager.restEndTime)
        #expect(rig.notifier.calls.first == .schedule(date: end, body: "Next: Bench Press, 60 kg × 8", sound: false))
    }

    /// With an activity the notification is only the backstop for a suspended app, so it is due a
    /// moment after the activity's own alert would go.
    @Test("Test With A Live Activity The Notification Waits Behind The Activity's Alert")
    func testWithALiveActivityTheNotificationWaitsBehindTheActivitysAlert() async throws {
        let rig = makeRig(showingLiveActivity: true)

        rig.manager.startRest(durationSeconds: 90, session: session)

        #expect(await TestManagers.eventually { rig.notifier.calls.count == 1 })
        let end = try #require(rig.manager.restEndTime)
        let due = try #require(scheduledDate(rig.notifier.calls.first))
        #expect(due == end.addingTimeInterval(HKWorkoutManager.restOverBackstopDelay))
    }

    /// +15s goes through `startRest` again, which moves the one pending request (same id) to the
    /// new end rather than leaving it at the old one.
    @Test("Test Lengthening A Rest Moves The Notification")
    func testLengtheningARestMovesTheNotification() async throws {
        let rig = makeRig(showingLiveActivity: false)

        rig.manager.startRest(durationSeconds: 60, session: session)
        rig.manager.startRest(durationSeconds: 75, session: session)

        #expect(await TestManagers.eventually { rig.notifier.calls.count == 2 })
        let end = try #require(rig.manager.restEndTime)
        #expect(scheduledDate(rig.notifier.calls.last) == end)
    }

    // MARK: - Withdrawing

    /// Skip, finish and discard all reach `cancelRest`, and a rest called off has nothing to say.
    /// The withdrawal lands after the schedule it follows, never before it.
    @Test("Test Skipping, Finishing And Discarding Withdraw The Notification", arguments: ["skip", "finish", "discard"])
    func testCallingOffARestWithdrawsTheNotification(action: String) async {
        let rig = makeRig(showingLiveActivity: false)
        rig.manager.startRest(durationSeconds: 90, session: session)

        switch action {
        case "skip": rig.manager.cancelRest()
        case "finish": rig.manager.endWorkout()
        default: rig.manager.discardWorkout()
        }

        #expect(await TestManagers.eventually { rig.notifier.calls.count == 2 })
        #expect(rig.notifier.calls.last == .cancel)
    }

    // MARK: - Running out

    /// On time with an activity showing: the activity alerts and the backstop is withdrawn, so the
    /// person hears one alert, not two.
    @Test("Test A Rest Running Out Alerts Through The Live Activity")
    func testARestRunningOutAlertsThroughTheLiveActivity() async {
        let rig = makeRig(showingLiveActivity: true)

        rig.manager.startRest(duration: Self.briefRest, session: session)

        #expect(await TestManagers.eventually { rig.activity.restOverAnnouncements == [true] })
        #expect(await TestManagers.eventually { rig.notifier.calls.last == .cancel })
    }

    /// With Live Activities off nothing is withdrawn: the notification due now is the alert.
    @Test("Test Without A Live Activity A Rest Running Out Leaves The Notification")
    func testWithoutALiveActivityARestRunningOutLeavesTheNotification() async {
        let rig = makeRig(showingLiveActivity: false)
        let posts = RestCompletionSpy(rig.manager)

        rig.manager.startRest(duration: Self.briefRest, session: session)

        #expect(await TestManagers.eventually { posts.count == 1 })
        #expect(rig.activity.restOverAnnouncements.isEmpty)
        #expect(!rig.notifier.calls.contains(.cancel))
    }

    /// The Live Activity's alert cannot be silent, so with Play Sound off the activity is only
    /// cleared: no alert, and no notification standing in for one.
    @Test("Test With Sound Off The Live Activity Clears Without Alerting")
    func testWithSoundOffTheLiveActivityClearsWithoutAlerting() async {
        let rig = makeRig(showingLiveActivity: true)

        rig.manager.startRest(duration: Self.briefRest, session: session, alertSound: false)

        #expect(await TestManagers.eventually { rig.notifier.calls.last == .cancel })
        #expect(rig.activity.restOverAnnouncements.isEmpty)
    }
}

}

#endif
