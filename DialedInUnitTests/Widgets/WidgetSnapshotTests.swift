//
//  WidgetSnapshotTests.swift
//  DialedInUnitTests
//
//  The home-screen widgets' data: the snapshot's round trip through the App Group, the timeline
//  the provider hands WidgetKit, what the app builds from its managers, and the widget's link.
//

import Foundation
import SwiftUI
import Testing
@testable import DialedIn

@MainActor
struct WidgetSnapshotTests {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        return calendar
    }

    /// Wednesday 23 September 2026, 10:00 UTC.
    private static let wednesday = Date(timeIntervalSince1970: 1_790_157_600)
    /// Sunday 27 September 2026, 10:00 UTC — the last day of a Monday-first week.
    private static let sunday = Date(timeIntervalSince1970: 1_790_503_200)

    private func snapshot(at now: Date) -> WidgetSnapshot {
        WidgetSnapshot(
            todaysWorkout: .init(name: "Push Day", exerciseCount: 5, isRestDay: false, isCompleted: false),
            day: Self.calendar.startOfDay(for: now),
            currentStreak: 4,
            sessionsThisWeek: 2,
            weeklyGoal: 3,
            updatedAt: now
        )
    }

    @Test("Test The Snapshot Survives An Encode Decode Round Trip")
    func testTheSnapshotSurvivesAnEncodeDecodeRoundTrip() throws {
        let original = snapshot(at: Self.wednesday)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test("Test The Store Reads Back What It Wrote")
    func testTheStoreReadsBackWhatItWrote() throws {
        let suite = "WidgetSnapshotTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(WidgetSnapshotStore.read(from: defaults) == nil)
        WidgetSnapshotStore.write(snapshot(at: Self.wednesday), to: defaults)
        #expect(WidgetSnapshotStore.read(from: defaults) == snapshot(at: Self.wednesday))
    }

    @Test("Test The Timeline Has An Entry Now And One At Midnight")
    func testTheTimelineHasAnEntryNowAndOneAtMidnight() throws {
        let entries = WidgetSnapshotTimeline.entries(snapshot: snapshot(at: Self.wednesday), now: Self.wednesday, calendar: Self.calendar)

        #expect(entries.map(\.date) == [
            Self.wednesday,
            try #require(Self.calendar.date(byAdding: .hour, value: 14, to: Self.wednesday))
        ])
        #expect(entries.map(\.snapshot) == [snapshot(at: Self.wednesday), snapshot(at: Self.wednesday)])
    }

    @Test("Test The Timeline Falls Back To An Empty Snapshot")
    func testTheTimelineFallsBackToAnEmptySnapshot() throws {
        let entry = try #require(WidgetSnapshotTimeline.entries(snapshot: nil, now: Self.wednesday, calendar: Self.calendar).first)
        #expect(entry.snapshot == .empty(now: Self.wednesday))
        #expect(entry.snapshot.todaysWorkout == nil)
        #expect(entry.snapshot.currentStreak == 0)
    }

    /// The midnight entry drops today's workout; within the week it keeps the count.
    @Test("Test The Midnight Entry Drops Today's Workout But Keeps The Week")
    func testTheMidnightEntryDropsTodaysWorkoutButKeepsTheWeek() throws {
        let entries = WidgetSnapshotTimeline.entries(snapshot: snapshot(at: Self.wednesday), now: Self.wednesday, calendar: Self.calendar)
        let now = entries[0], midnight = entries[1]

        #expect(now.snapshot.todaysWorkout(on: now.date, calendar: Self.calendar)?.name == "Push Day")
        #expect(midnight.snapshot.todaysWorkout(on: midnight.date, calendar: Self.calendar) == nil)
        #expect(midnight.snapshot.sessionsThisWeek(on: midnight.date, calendar: Self.calendar) == 2)
    }

    @Test("Test A New Week Empties The Ring")
    func testANewWeekEmptiesTheRing() {
        let entries = WidgetSnapshotTimeline.entries(snapshot: snapshot(at: Self.sunday), now: Self.sunday, calendar: Self.calendar)

        #expect(entries[0].snapshot.sessionsThisWeek(on: entries[0].date, calendar: Self.calendar) == 2)
        #expect(entries[1].snapshot.sessionsThisWeek(on: entries[1].date, calendar: Self.calendar) == 0)
        #expect(entries[1].snapshot.weeklyProgress(on: entries[1].date, calendar: Self.calendar) == 0)
    }

    @Test("Test The Ring Never Passes Full")
    func testTheRingNeverPassesFull() {
        var over = snapshot(at: Self.wednesday)
        over.sessionsThisWeek = 7
        #expect(over.weeklyProgress(on: Self.wednesday, calendar: Self.calendar) == 1)
    }

    // MARK: - Built from the app's data

    private func program(template: WorkoutTemplateModel) -> TrainingProgram {
        TrainingProgram(id: "program-1", authorId: "user-1", name: "Block", icon: "dumbbell", colour: "#FF0000", workoutTemplates: [template])
    }

    @Test("Test The App Builds Today's Workout And The Week From Its Sessions")
    func testTheAppBuildsTodaysWorkoutAndTheWeekFromItsSessions() throws {
        let template = WorkoutTemplateModel.mock
        try #require(!template.exercises.isEmpty)
        let finished = WorkoutSessionModel(
            authorId: "user-1",
            name: template.name,
            workoutTemplateId: template.id,
            trainingProgramId: "program-1",
            dateCreated: Self.wednesday,
            endedAt: Self.wednesday,
            exercises: []
        )
        let someoneElse = WorkoutSessionModel(authorId: "user-2", name: "Legs", dateCreated: Self.wednesday, endedAt: Self.wednesday, exercises: [])

        let built = WidgetSnapshot.make(
            userId: "user-1",
            program: program(template: template),
            sessions: [finished, someoneElse],
            streak: 9,
            weeklyGoal: 4,
            now: Self.wednesday,
            calendar: Self.calendar
        )

        #expect(built.todaysWorkout == .init(name: template.name, exerciseCount: template.exercises.count, isRestDay: false, isCompleted: true))
        #expect(built.day == Self.calendar.startOfDay(for: Self.wednesday))
        #expect(built.currentStreak == 9)
        #expect(built.sessionsThisWeek == 1)
        #expect(built.weeklyGoal == 4)
    }

    @Test("Test No Program Means No Workout Today")
    func testNoProgramMeansNoWorkoutToday() {
        let built = WidgetSnapshot.make(userId: "user-1", program: nil, sessions: [], streak: nil, weeklyGoal: 3, now: Self.wednesday, calendar: Self.calendar)
        #expect(built.todaysWorkout == nil)
        #expect(built.currentStreak == 0)
        #expect(built.sessionsThisWeek == 0)
    }

    // MARK: - The widget's link

    @Test("Test The Widget Link Parses As The Workout Destination")
    func testTheWidgetLinkParsesAsTheWorkoutDestination() {
        #expect(DeepLink(url: WidgetSnapshotStore.workoutURL) == .workout)
    }

    @Test("Test The Workout Link Opens The Tracker When A Session Is Under Way")
    func testTheWorkoutLinkOpensTheTrackerWhenASessionIsUnderWay() {
        let interactor = TabBarInteractorDouble()
        interactor.activeSession = WorkoutSessionModel(authorId: "user-1", name: "Push", dateCreated: Self.wednesday, exercises: [])
        let router = TabBarRouterDouble()
        let presenter = TabBarPresenter(interactor: interactor, router: router)
        presenter.selectedTabTitle = "Nutrition"

        presenter.onOpenURL(WidgetSnapshotStore.workoutURL)

        #expect(router.trackerShown == 1)
        #expect(presenter.selectedTabTitle == "Nutrition")
        #expect(interactor.trackedEventNames == ["TabBarView_DeepLink_Workout"])
    }

    @Test("Test The Workout Link Lands On The Dashboard With Nothing Under Way")
    func testTheWorkoutLinkLandsOnTheDashboardWithNothingUnderWay() {
        let router = TabBarRouterDouble()
        let presenter = TabBarPresenter(interactor: TabBarInteractorDouble(), router: router)
        presenter.selectedTabTitle = "Nutrition"

        presenter.onOpenURL(WidgetSnapshotStore.workoutURL)

        #expect(router.trackerShown == 0)
        #expect(presenter.selectedTabTitle == "Dashboard")
    }

    private final class TabBarInteractorDouble: SpyGlobalInteractor, TabBarInteractor {
        func consumePendingDeepLink() -> DeepLink? { nil }
        var activeSession: WorkoutSessionModel?
        var draftMeal: MealLogModel?
        var activityNotifications: [ActivityNotificationModel] = []
        var incomingFollowRequests: [FollowRequestModel] = []
    }

    private final class TabBarRouterDouble: TabBarRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var trackerShown = 0

        func showWorkoutTrackerView() { trackerShown += 1 }
        func showAlert(error: Error) { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
    }
}
