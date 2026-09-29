//
//  ReviewPromptPolicyTests.swift
//  DialedInUnitTests
//

import Foundation
import Testing
@testable import DialedIn

/// Serialized: the Dashboard cases go through `UserDefaults.standard`, which the presenter reads.
@MainActor
@Suite(.serialized)
struct ReviewPromptPolicyTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func session(isRestDay: Bool = false, setDone: Bool = true) -> WorkoutSessionModel {
        let set = WorkoutSetModel(id: "set", authorId: "me", index: 1, reps: 5, weightKg: 60, isWarmup: false, completedAt: setDone ? now : nil, dateCreated: now)
        return WorkoutSessionModel(
            id: UUID().uuidString,
            authorId: "me",
            name: "Push",
            dateCreated: now,
            endedAt: now,
            exercises: isRestDay ? [] : [WorkoutExerciseModel(id: "e", authorId: "me", templateId: "bench", name: "Bench", trackingMode: .weightReps, index: 1, sets: [set])],
            isRestDay: isRestDay
        )
    }

    private func freshStore() -> ReviewPromptStore {
        let name = "ReviewPromptPolicyTests-\(UUID().uuidString)"
        return ReviewPromptStore(defaults: UserDefaults(suiteName: name)!)
    }

    // MARK: Policy

    @Test("Test A Review Is Requested From The Third Session")
    func testAReviewIsRequestedFromTheThirdSession() {
        let results = (1...4).map {
            ReviewPromptPolicy.shouldRequestReview(completedSessions: $0, lastRequestedAt: .distantPast, now: now, isUITesting: false)
        }
        #expect(results == [false, false, true, true])
    }

    @Test("Test No Second Request Within 120 Days")
    func testNoSecondRequestWithin120Days() {
        let day: TimeInterval = 24 * 60 * 60
        let within = ReviewPromptPolicy.shouldRequestReview(completedSessions: 9, lastRequestedAt: now - 119 * day, now: now, isUITesting: false)
        let after = ReviewPromptPolicy.shouldRequestReview(completedSessions: 9, lastRequestedAt: now - 120 * day, now: now, isUITesting: false)
        #expect(!within)
        #expect(after)
    }

    @Test("Test Never Requested In UI Testing")
    func testNeverRequestedInUITesting() {
        #expect(!ReviewPromptPolicy.shouldRequestReview(completedSessions: 3, lastRequestedAt: .distantPast, now: now, isUITesting: true))
    }

    @Test("Test Only A Real Session Counts")
    func testOnlyARealSessionCounts() {
        #expect(ReviewPromptPolicy.counts(session()))
        #expect(!ReviewPromptPolicy.counts(session(isRestDay: true)))
        #expect(!ReviewPromptPolicy.counts(session(setDone: false)))
    }

    @Test("Test The Invite Card Shows From The Fifth Session Until Dismissed")
    func testTheInviteCardShowsFromTheFifthSessionUntilDismissed() {
        #expect(!ReviewPromptPolicy.showsInviteCard(completedSessions: 4, inviteCardDismissed: false))
        #expect(ReviewPromptPolicy.showsInviteCard(completedSessions: 5, inviteCardDismissed: false))
        #expect(!ReviewPromptPolicy.showsInviteCard(completedSessions: 5, inviteCardDismissed: true))
    }

    // MARK: Store

    @Test("Test The Store Counts Real Sessions And Asks On The Third")
    func testTheStoreCountsRealSessionsAndAsksOnTheThird() {
        let store = freshStore()
        let asks = [session(), session(isRestDay: true), session(), session()].map {
            store.recordFinishedSession($0, lastRequestedAt: .distantPast, now: now, isUITesting: false)
        }
        #expect(asks == [false, false, false, true])
        #expect(store.completedSessions == 3)
    }

    // MARK: Dashboard card

    private func withStandardDefaults(sessions: Int, dismissed: Bool, _ body: () async throws -> Void) async rethrows {
        let defaults = UserDefaults.standard
        defaults.set(sessions, forKey: ReviewPromptStore.completedSessionsKey)
        defaults.set(dismissed, forKey: ReviewPromptStore.inviteCardDismissedKey)
        defer {
            defaults.removeObject(forKey: ReviewPromptStore.completedSessionsKey)
            defaults.removeObject(forKey: ReviewPromptStore.inviteCardDismissedKey)
        }
        try await body()
    }

    @MainActor
    private struct Screen {
        let interactor = DashboardFeedPresenterTests.Interactor()
        let router = DashboardFeedPresenterTests.Router()
        let presenter: DashboardPresenter

        init() { presenter = DashboardPresenter(interactor: interactor, router: router) }
    }

    @Test("Test The Dashboard Card Waits For The Fifth Session")
    func testTheDashboardCardWaitsForTheFifthSession() async {
        await withStandardDefaults(sessions: 4, dismissed: false) {
            #expect(!Screen().presenter.showsInviteCard)
        }
        await withStandardDefaults(sessions: 5, dismissed: false) {
            #expect(Screen().presenter.showsInviteCard)
        }
    }

    @Test("Test Tapping The Card Opens The Invite Share Once")
    func testTappingTheCardOpensTheInviteShareOnce() async {
        await withStandardDefaults(sessions: 5, dismissed: false) {
            let screen = Screen(), presenter = screen.presenter, router = screen.router
            presenter.onInviteCardPressed()
            #expect(!presenter.showsInviteCard)
            #expect(await TestManagers.eventually { router.shown == ["share: Train with me on Compound: compound://join/PUSH2345"] })
            #expect(!Screen().presenter.showsInviteCard)
        }
    }

    @Test("Test Closing The Card Hides It For Good")
    func testClosingTheCardHidesItForGood() async {
        await withStandardDefaults(sessions: 5, dismissed: false) {
            let screen = Screen(), presenter = screen.presenter, router = screen.router
            presenter.onInviteCardDismissed()
            #expect(!presenter.showsInviteCard)
            #expect(router.shown.isEmpty)
            #expect(!Screen().presenter.showsInviteCard)
        }
    }

    @Test("Test A Failed Invite Shows An Alert")
    func testAFailedInviteShowsAnAlert() async {
        await withStandardDefaults(sessions: 5, dismissed: false) {
            let screen = Screen(), presenter = screen.presenter, router = screen.router
            let interactor = screen.interactor
            interactor.inviteFails = true
            presenter.onInviteCardPressed()
            #expect(await TestManagers.eventually { router.alertTitles == ["Couldn't create invite"] })
        }
    }
}
