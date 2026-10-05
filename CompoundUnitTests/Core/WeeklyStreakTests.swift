//
//  WeeklyStreakTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The app's one streak: weeks in a row with the weekly session goal met.
///
/// Weeks run Monday to Sunday in UTC here. "Now" is Saturday 14 March 2026, so the current week is
/// 9–15 March, with Saturday and Sunday left.
@MainActor
struct WeeklyStreakTests {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }()

    /// 18:00 on `day` March 2026; days before 1 reach back into February.
    private static func date(_ day: Int, hour: Int = 18) -> Date {
        let first = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: hour)) ?? .distantPast
        return calendar.date(byAdding: .day, value: day - 1, to: first) ?? first
    }

    private static let now = date(14)

    private func session(
        day: Int,
        hour: Int = 9,
        author: String = "me",
        isRestDay: Bool = false,
        finished: Bool = true,
        deleted: Bool = false
    ) -> WorkoutSessionModel {
        let start = Self.date(day, hour: hour)
        return WorkoutSessionModel(
            id: UUID().uuidString,
            authorId: author,
            name: "Session",
            dateCreated: start,
            endedAt: finished ? start.addingTimeInterval(3_600) : nil,
            exercises: [],
            deletedAt: deleted ? start : nil,
            isRestDay: isRestDay
        )
    }

    /// `count` sessions in the week containing `day`, on consecutive days from that week's Monday.
    private func week(of day: Int, count: Int) -> [WorkoutSessionModel] {
        let monday = Self.calendar.dateInterval(of: .weekOfYear, for: Self.date(day))?.start ?? Self.date(day)
        let mondayDay = Self.calendar.dateComponents([.day], from: Self.date(1, hour: 0), to: monday).day ?? 0
        return (0..<count).map { session(day: mondayDay + 1 + $0) }
    }

    private func streak(_ sessions: [WorkoutSessionModel], goal: Int = 3, now: Date = now) -> WeeklyStreak {
        WeeklyStreak.make(sessions: sessions, userId: "me", goal: goal, now: now, calendar: Self.calendar)
    }

    // MARK: - What counts

    @Test("Test Rest Days Unfinished Deleted And Others Sessions Never Count")
    func testRestDaysUnfinishedDeletedAndOthersSessionsNeverCount() {
        let result = streak([
            session(day: 9),
            session(day: 10, isRestDay: true),
            session(day: 11, finished: false),
            session(day: 12, deleted: true),
            session(day: 12, author: "friend")
        ])

        #expect(result.sessionsThisWeek == 1)
        #expect(result.weeks == 0)
    }

    // MARK: - The count

    /// This week counts once its goal is met, and so does every met week before it.
    @Test("Test Consecutive Met Weeks Count This Week Once Met")
    func testConsecutiveMetWeeksCountThisWeekOnceMet() {
        let result = streak(week(of: 14, count: 3) + week(of: 7, count: 3) + week(of: 0, count: 4))

        #expect(result.weeks == 3)
        #expect(result.state == .met)
    }

    /// A week still under way has not failed yet, so it does not break the streak behind it.
    @Test("Test A Week Under Way Does Not Break The Streak")
    func testAWeekUnderWayDoesNotBreakTheStreak() {
        let result = streak([session(day: 14)] + week(of: 7, count: 3) + week(of: 0, count: 3))

        #expect(result.weeks == 2)
        #expect(result.sessionsThisWeek == 1)
        #expect(result.sessionsRemaining == 2)
        #expect(result.state == .onTrack)
    }

    @Test("Test A Missed Week Ends The Streak")
    func testAMissedWeekEndsTheStreak() {
        // Two weeks ago met, last week two of three: nothing carries over.
        let result = streak(week(of: 7, count: 2) + week(of: 0, count: 3))

        #expect(result.weeks == 0)
        #expect(result.state == .none)
        #expect(result.best == 1)
    }

    @Test("Test The Best Streak Is The Longest Run")
    func testTheBestStreakIsTheLongestRun() {
        // Four met weeks in February, a gap, then last week met again.
        let february = [-20, -13, -6].flatMap { week(of: $0, count: 3) } + week(of: -27, count: 3)
        let result = streak(week(of: 7, count: 3) + february)

        #expect(result.weeks == 1)
        #expect(result.best == 4)
    }

    // MARK: - At risk

    /// Saturday, one of three: two owed, two days left, nothing today. Every day is now needed.
    @Test("Test Owing As Many Sessions As Days Left Is At Risk")
    func testOwingAsManySessionsAsDaysLeftIsAtRisk() {
        let result = streak([session(day: 10)] + week(of: 7, count: 3))

        #expect(result.daysRemaining == 2)
        #expect(result.sessionsRemaining == 2)
        #expect(result.state == .atRisk)
    }

    @Test("Test Training Today Is Not At Risk")
    func testTrainingTodayIsNotAtRisk() {
        // Last week met a goal of four; today's session leaves three owed with two days left.
        let result = streak([session(day: 14, hour: 7)] + week(of: 7, count: 4), goal: 4)

        #expect(result.weeks == 1)
        #expect(result.trainedToday)
        #expect(result.state == .onTrack)
    }

    /// With no streak there is nothing to lose: owing every day left is only "on track" to start one.
    @Test("Test Without A Streak Nothing Is At Risk")
    func testWithoutAStreakNothingIsAtRisk() {
        #expect(streak([session(day: 10)]).state == .onTrack)
    }

    // MARK: - The server's copy

    /// The evening reminder works from these: when the week ends, and when the user last trained.
    @Test("Test The Week End And Last Session Are Reported")
    func testTheWeekEndAndLastSessionAreReported() {
        let result = streak([session(day: 10, hour: 9), session(day: 12, hour: 7)])

        #expect(result.weekEndsAt == Self.date(16, hour: 0))
        #expect(result.lastTrainedAt == Self.date(12, hour: 7))
    }

    @Test("Test Recording Writes The Streak Into The Private Settings")
    func testRecordingWritesTheStreakIntoThePrivateSettings() {
        let result = streak([session(day: 10)] + week(of: 7, count: 3))

        let recorded = PrivateUserSettings(fcmToken: "tok").recording(result)

        #expect(recorded.fcmToken == "tok")
        #expect(recorded.weekStreak == 1)
        #expect(recorded.weekSessions == 1)
        #expect(recorded.weekGoal == 3)
        #expect(recorded.weekEndsAt == result.weekEndsAt)
        #expect(recorded.lastTrainedAt == Self.date(10, hour: 9))
        #expect(recorded.recording(result) == recorded)
    }
}

/// The streak card on Today.
@MainActor
struct WorkoutStreakPresenterTests {

    private final class Interactor: SpyGlobalInteractor, WorkoutStreakInteractor {
        var workoutSessions: [WorkoutSessionModel] = []
        var weeklyStreak = WeeklyStreak.fixture(weeks: 0)
    }

    private final class Router: WorkoutStreakRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    @Test("Test The Card Reads Weeks And This Weeks Progress")
    func testTheCardReadsWeeksAndThisWeeksProgress() {
        let interactor = Interactor()
        interactor.weeklyStreak = WeeklyStreak(
            weeks: 6, best: 9, sessionsThisWeek: 2, goal: 3, daysRemaining: 3,
            trainedToday: true, weekEndsAt: Date(), lastTrainedAt: Date()
        )
        let presenter = WorkoutStreakPresenter(interactor: interactor, router: Router())

        #expect(presenter.weeksText == "6 weeks")
        #expect(presenter.bestText == "9 weeks")
        #expect(presenter.thisWeekText == "2 of 3 this week")
    }

    /// The dots mark days that count toward the goal: a rest day is not one.
    @Test("Test The Week's Dots Leave Out Rest Days")
    func testTheWeeksDotsLeaveOutRestDays() {
        let interactor = Interactor()
        let today = Calendar.current.startOfDay(for: .now)
        interactor.workoutSessions = [
            WorkoutSessionModel(authorId: "me", name: "Push", dateCreated: today.addingTimeInterval(3_600), endedAt: today.addingTimeInterval(7_200), exercises: []),
            WorkoutSessionModel(authorId: "me", name: "Rest", dateCreated: today.addingTimeInterval(3_600), endedAt: today.addingTimeInterval(3_600), exercises: [], isRestDay: true)
        ]
        let presenter = WorkoutStreakPresenter(interactor: interactor, router: Router())

        #expect(presenter.workoutDaysThisWeek == [today])
        #expect(presenter.totalWorkouts == 1)
    }
}
