//
//  CircleWeekTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

/// The circle's week: bucketing, goals, ranking and the Monday recap. A fixed Monday-start
/// calendar in UTC so the week boundaries do not depend on the machine running the tests.
@MainActor
struct CircleWeekTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private func session(_ id: String, _ author: String, _ date: Date, volume: Double = 0) -> WorkoutSessionModel {
        let sets = volume > 0
            ? [WorkoutSetModel(id: "\(id)-set", authorId: author, index: 1, reps: 1, weightKg: volume, isWarmup: false, completedAt: date, dateCreated: date)]
            : []
        let exercises = sets.isEmpty
            ? []
            : [WorkoutExerciseModel(id: "\(id)-ex", authorId: author, templateId: "bench", name: "Bench", trackingMode: .weightReps, index: 1, sets: sets)]
        return DashboardFixture.session(id: id, author: author, on: date, exercises: exercises)
    }

    private func count(_ author: String, inWeekOf date: Date, _ sessions: [WorkoutSessionModel]) -> Int {
        CircleWeek.sessionCount(of: author, inWeekOf: date, sessions: sessions, calendar: calendar)
    }

    // MARK: Bucketing

    /// Sunday 8 March 2026 closes one week and Monday 9 March opens the next.
    @Test("Test Sunday And Monday Fall In Different Weeks")
    func testSundayAndMondayFallInDifferentWeeks() {
        let sessions = [
            session("mon", "me", date(2026, 3, 2)),
            session("sun", "me", date(2026, 3, 8, hour: 23)),
            session("nextMon", "me", date(2026, 3, 9, hour: 0))
        ]
        #expect(count("me", inWeekOf: date(2026, 3, 8), sessions) == 2)
        #expect(count("me", inWeekOf: date(2026, 3, 9), sessions) == 1)
        #expect(CircleWeek.isLastDayOfWeek(date(2026, 3, 8), calendar: calendar))
        #expect(!CircleWeek.isLastDayOfWeek(date(2026, 3, 7), calendar: calendar))
        #expect(CircleWeek.isFirstDayOfWeek(date(2026, 3, 9), calendar: calendar))
        #expect(!CircleWeek.isFirstDayOfWeek(date(2026, 3, 10), calendar: calendar))
    }

    /// Monday 29 December 2025 to Sunday 4 January 2026 is one week, across the year change.
    @Test("Test A Week Spanning New Year Is One Week")
    func testAWeekSpanningNewYearIsOneWeek() {
        let sessions = [
            session("a", "me", date(2025, 12, 29)),
            session("b", "me", date(2025, 12, 31)),
            session("c", "me", date(2026, 1, 1)),
            session("d", "me", date(2026, 1, 4)),
            session("e", "me", date(2026, 1, 5))
        ]
        #expect(count("me", inWeekOf: date(2026, 1, 2), sessions) == 4)
        #expect(count("me", inWeekOf: date(2025, 12, 28), sessions) == 0)
        #expect(CircleWeek.weekId(for: date(2025, 12, 31), calendar: calendar) == CircleWeek.weekId(for: date(2026, 1, 4), calendar: calendar))
        #expect(CircleWeek.weekId(for: date(2026, 1, 4), calendar: calendar) != CircleWeek.weekId(for: date(2026, 1, 5), calendar: calendar))
    }

    /// Only the author's finished, non-rest sessions count, as on the feed.
    @Test("Test Only Finished Non Rest Sessions By The Author Count")
    func testOnlyFinishedNonRestSessionsByTheAuthorCount() {
        let day = date(2026, 3, 4)
        let sessions = [
            session("mine", "me", day),
            DashboardFixture.session(id: "rest", author: "me", on: day, isRestDay: true),
            DashboardFixture.session(id: "open", author: "me", on: day, finished: false),
            session("theirs", "amy", day)
        ]
        #expect(count("me", inWeekOf: day, sessions) == 1)
    }

    // MARK: Goals

    @Test("Test An Unset Goal Reads As Three And A Stored One Is Clamped")
    func testAnUnsetGoalReadsAsThreeAndAStoredOneIsClamped() {
        #expect(CircleWeek.goal(for: UserModel(userId: "a")) == 3)
        #expect(CircleWeek.goal(for: UserModel(userId: "a", weeklySessionGoal: 5)) == 5)
        #expect(CircleWeek.goal(for: UserModel(userId: "a", weeklySessionGoal: 0)) == 1)
        #expect(CircleWeek.goal(for: UserModel(userId: "a", weeklySessionGoal: 12)) == 7)
    }

    @Test("Test Progress Is Clamped Between Empty And Full")
    func testProgressIsClampedBetweenEmptyAndFull() {
        #expect(CircleWeek.progress(sessions: 0, goal: 3) == 0)
        #expect(CircleWeek.progress(sessions: 3, goal: 4) == 0.75)
        #expect(CircleWeek.progress(sessions: 6, goal: 3) == 1)
        #expect(CircleWeek.remaining(sessions: 1, goal: 3) == 2)
        #expect(CircleWeek.remaining(sessions: 5, goal: 3) == 0)
    }

    // MARK: Ranking

    /// Sessions first, then volume, then name — so equal sessions and volume fall back to A–Z.
    @Test("Test Ranking Breaks Ties On Volume Then Name")
    func testRankingBreaksTiesOnVolumeThenName() {
        let day = date(2026, 3, 4)
        let users = ["cal", "bob", "amy", "dee"].map { DashboardFixture.user($0, firstName: $0.capitalized) }
        let sessions = [
            session("d1", "dee", day), session("d2", "dee", day), session("d3", "dee", day),
            session("b1", "bob", day, volume: 500), session("b2", "bob", day),
            session("c1", "cal", day, volume: 900), session("c2", "cal", day),
            session("a1", "amy", day), session("a2", "amy", day, volume: 900)
        ]

        let ranked = CircleWeek.standings(users: users, sessions: sessions, now: day, calendar: calendar)

        #expect(ranked.map(\.id) == ["dee", "amy", "cal", "bob"])
        #expect(ranked.map(\.sessions) == [3, 2, 2, 2])
    }

    // MARK: Monday recap

    @Test("Test The Recap Shows On Monday Until Dismissed For That Week")
    func testTheRecapShowsOnMondayUntilDismissedForThatWeek() throws {
        let reader = UserModel(userId: "me", weeklySessionGoal: 3)
        let amy = DashboardFixture.user("amy")
        let sessions = [
            session("m1", "me", date(2026, 3, 3)), session("m2", "me", date(2026, 3, 5)), session("m3", "me", date(2026, 3, 8)),
            session("a1", "amy", date(2026, 3, 4)), session("a2", "amy", date(2026, 3, 6)),
            session("thisWeek", "me", date(2026, 3, 9, hour: 7))
        ]
        let monday = date(2026, 3, 9)

        func summary(on now: Date, dismissed: String? = nil) -> CircleWeek.Summary? {
            CircleWeek.summary(reader: reader, circle: [reader, amy], sessions: sessions, now: now, dismissedWeekId: dismissed, calendar: calendar)
        }

        let shown = try #require(summary(on: monday))
        #expect(shown.text == "Last week: you 3/3, circle 5 sessions")
        #expect(summary(on: date(2026, 3, 10)) == nil)
        #expect(summary(on: monday, dismissed: shown.weekId) == nil)
        // Last week's dismissal does not hide this week's recap.
        #expect(summary(on: monday, dismissed: CircleWeek.weekId(for: date(2026, 3, 2), calendar: calendar)) != nil)
    }
}
