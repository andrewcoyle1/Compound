//
//  StreakVisibilityTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

/// A streak is stamped on the session when its author finishes it, because followers cannot read
/// anyone else's streak. These check where it is read back: the feed card and the profile header.
/// The doubles are the ones `SocialWorkoutSessionRowTests` and `SocialProfilePresenterTests` use.
@MainActor
struct StreakVisibilityTests {

    private func session(id: String, day: Int, streak: Int?) -> WorkoutSessionModel {
        var session = DashboardFixture.session(id: id, author: "friend", on: DashboardFixture.date(day: day))
        session.streakCount = streak
        return session
    }

    // MARK: Feed card

    private func rowStreakText(_ streak: Int?) -> String? {
        WorkoutSessionRowPresenter(
            interactor: SocialWorkoutSessionRowTests.Interactor(),
            router: SocialWorkoutSessionRowTests.Router(),
            delegate: WorkoutSessionRowDelegate(session: session(id: "s", day: 2, streak: streak), author: DashboardFixture.user("friend"))
        ).streakText
    }

    /// Older sessions have no count and render as before; a one-day streak is not news.
    @Test("Test The Streak Capsule Shows Only For A Stamped Count Above One")
    func testTheStreakCapsuleShowsOnlyForAStampedCountAboveOne() {
        #expect(rowStreakText(nil) == nil)
        #expect(rowStreakText(0) == nil)
        #expect(rowStreakText(1) == nil)
        #expect(rowStreakText(2) == "2-day streak")
        #expect(rowStreakText(12) == "12-day streak")
    }

    /// The field is optional on the wire, so a document written before it existed still decodes.
    @Test("Test A Session Without The Streak Field Still Decodes")
    func testASessionWithoutTheStreakFieldStillDecodes() throws {
        let stamped = session(id: "s", day: 2, streak: 7)
        let data = try JSONEncoder().encode(stamped)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["streak_count"] as? Int == 7)

        json.removeValue(forKey: "streak_count")
        let legacy = try JSONDecoder().decode(WorkoutSessionModel.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(legacy.streakCount == nil)
    }

    // MARK: Profile header

    private func profileStreak(sessions: [WorkoutSessionModel]) async -> Int? {
        let interactor = SocialProfilePresenterTests.Interactor()
        interactor.remoteSessions = sessions
        let presenter = SocialProfilePresenter(interactor: interactor, router: SocialProfilePresenterTests.Router())
        presenter.onViewAppear(delegate: SocialProfileDelegate(user: DashboardFixture.user("friend")))
        _ = await TestManagers.eventually { presenter.sessions.count == sessions.count }
        return presenter.latestStreak
    }

    /// The newest session that carries a count wins, even when a later one does not carry any.
    @Test("Test The Profile Reads The Streak Off The Latest Stamped Session")
    func testTheProfileReadsTheStreakOffTheLatestStampedSession() async {
        let streak = await profileStreak(sessions: [
            session(id: "old", day: 1, streak: 9),
            session(id: "unstamped", day: 5, streak: nil),
            session(id: "latest", day: 4, streak: 5)
        ])
        #expect(streak == 5)
    }

    @Test("Test The Profile Shows No Streak Without One Above One")
    func testTheProfileShowsNoStreakWithoutOneAboveOne() async {
        #expect(await profileStreak(sessions: [session(id: "a", day: 1, streak: nil)]) == nil)
        #expect(await profileStreak(sessions: [session(id: "b", day: 2, streak: 1), session(id: "c", day: 1, streak: 8)]) == nil)
    }
}
