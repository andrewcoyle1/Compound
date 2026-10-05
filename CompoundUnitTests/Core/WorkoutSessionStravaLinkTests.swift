//
//  WorkoutSessionStravaLinkTests.swift
//  CompoundUnitTests
//
//  The session screen's side of the Strava upload: the link to the activity and sending edited
//  notes to it. In its own file because the presenter suite is at its length limit.
//

import Testing
import Foundation
@testable import Compound

extension WorkoutSessionDetailPresenterTests {

    /// The summary opens with the session as finished, before Strava has made the activity. The
    /// id lands on the stored session, so the link reads from there.
    @Test("Test The Strava Link Reads The Stored Session")
    func testTheStravaLinkReadsTheStoredSession() {
        let screen = makeScreen()
        let workout = session(exercises: [])
        var stored = workout
        stored.stravaActivityId = 42
        #expect(screen.presenter.stravaLink(session: workout) == nil)

        screen.interactor.storedSessions = [stored]

        #expect(screen.presenter.stravaLink(session: workout)?.absoluteString == "https://www.strava.com/activities/42")
    }

    @Test("Test Only The Author Sees The Strava Link")
    func testOnlyTheAuthorSeesTheStravaLink() {
        let screen = makeScreen(user: UserModel(userId: "reader"))
        var workout = session(exercises: [])
        workout.stravaActivityId = 42

        #expect(screen.presenter.stravaLink(session: workout) == nil)
    }

    /// The description lists the sets as well as the notes, so a saved edit goes to Strava.
    @Test("Test A Saved Edit Is Sent To Strava")
    func testASavedEditIsSentToStrava() async {
        let screen = makeScreen()
        screen.interactor.stravaIsConnected = true
        var linked = session(exercises: [])
        linked.stravaActivityId = 42
        let workout = MutableSession(linked)
        let original = workout.value
        workout.value.notes = "Felt strong"

        await screen.presenter.saveChanges(initialSession: original, session: workout.binding)

        #expect(await TestManagers.eventually { screen.interactor.stravaUpdates.map(\.activityId) == [42] })
        #expect(screen.interactor.stravaUpdates.first?.session.notes == "Felt strong")
    }

    @Test("Test A Session Not On Strava Sends Nothing")
    func testASessionNotOnStravaSendsNothing() async throws {
        let screen = makeScreen()
        screen.interactor.stravaIsConnected = true
        let workout = MutableSession(session(exercises: []))
        let original = workout.value
        workout.value.notes = "Felt strong"

        await screen.presenter.saveChanges(initialSession: original, session: workout.binding)
        try await Task.sleep(for: .milliseconds(50))

        #expect(screen.interactor.stravaUpdates.isEmpty)
    }
}
