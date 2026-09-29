//
//  WorkoutSessionManagerTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import DialedIn

/// The logged workouts, and the one in progress.
///
/// The session being tracked is held in its own local document rather than in the synced
/// collection, so an unfinished workout survives the app being killed mid-set without ever
/// appearing in the history. Keeping those two apart is the behaviour worth pinning.
@MainActor
struct WorkoutSessionManagerTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func exercise(templateId: String) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "\(templateId)-instance",
            authorId: "author-1",
            templateId: templateId,
            name: templateId,
            trackingMode: .weightReps,
            index: 1,
            sets: []
        )
    }

    private func session(
        id: String,
        templateId: String? = nil,
        programId: String? = nil,
        daysAgo: Int = 0,
        ended: Bool = true,
        exerciseTemplateIds: [String] = []
    ) -> WorkoutSessionModel {
        let date = start.addingTimeInterval(Double(-daysAgo) * 86400)
        return WorkoutSessionModel(
            id: id,
            authorId: "author-1",
            name: "Push Day",
            workoutTemplateId: templateId,
            trainingProgramId: programId,
            dateCreated: date,
            endedAt: ended ? date.addingTimeInterval(3600) : nil,
            exercises: exerciseTemplateIds.map { exercise(templateId: $0) }
        )
    }

    private var history: [WorkoutSessionModel] {
        [
            session(id: "s1", templateId: "push", daysAgo: 10),
            session(id: "s2", templateId: "pull", daysAgo: 5),
            session(id: "s3", templateId: "push", daysAgo: 1)
        ]
    }

    // MARK: - History

    @Test("Test Sessions Are Empty Until Signed In")
    func testSessionsAreEmptyUntilSignedIn() {
        #expect(TestManagers.workoutSessionManager(sessions: history).workoutSessions.isEmpty)
    }

    @Test("Test Signing In Loads The History")
    func testSigningInLoadsTheHistory() async {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: history)

        #expect(manager.workoutSessions.count == 3)
    }

    /// Another person's sessions live under their own user document, not the reader's, so the
    /// lookup must not go through the reader's collection — it used to, and always came back empty.
    @Test("Test Sessions For Another Author Come From Their Collection")
    func testSessionsForAnotherAuthorComeFromTheirCollection() async throws {
        let manager = TestManagers.workoutSessionManager(
            sessions: history,
            following: [
                DashboardFixture.session(id: "f1", author: "friend", on: start),
                DashboardFixture.session(id: "o1", author: "other", on: start)
            ]
        )

        let sessions = try await manager.getWorkoutSessionsForAuthor(authorId: "friend")

        #expect(sessions.map(\.id) == ["f1"])
    }

    /// A notification names one session by id and author; anyone's can be fetched, and an id that
    /// is not there throws rather than returning some other session.
    @Test("Test Fetching One Session By Id And Author")
    func testFetchingOneSessionByIdAndAuthor() async throws {
        let manager = TestManagers.workoutSessionManager(
            following: [
                DashboardFixture.session(id: "f1", author: "friend", on: start),
                DashboardFixture.session(id: "f2", author: "friend", on: start)
            ]
        )

        #expect(try await manager.fetchWorkoutSession(id: "f2", authorId: "friend").id == "f2")
        await #expect(throws: (any Error).self) {
            try await manager.fetchWorkoutSession(id: "missing", authorId: "friend")
        }
    }

    @Test("Test Reading Sessions By Id")
    func testReadingSessionsById() async {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: history)

        #expect(manager.getWorkoutSessions(ids: ["s1", "s3"]).map(\.id).sorted() == ["s1", "s3"])
        #expect(manager.getWorkoutSessions(ids: ["nope"]).isEmpty)
        #expect(manager.getWorkoutSessions(ids: []).isEmpty)
    }

    @Test("Test Reading Sessions Honours A Limit")
    func testReadingSessionsHonoursALimit() async {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: history)

        #expect(manager.getWorkoutSessions(ids: ["s1", "s2", "s3"], limitTo: 2).count == 2)
    }

    /// What "last time" means on an exercise screen: the most recent session of that workout, not
    /// merely the first one found.
    @Test("Test The Last Session For A Template Is The Most Recent")
    func testTheLastSessionForATemplateIsTheMostRecent() async throws {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: history)

        let last = try await manager.getLastWorkoutSessionForTemplate(templateId: "push")

        #expect(last?.id == "s3")
    }

    @Test("Test A Template Never Trained Has No Last Session")
    func testATemplateNeverTrainedHasNoLastSession() async throws {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: history)

        #expect(try await manager.getLastWorkoutSessionForTemplate(templateId: "legs") == nil)
    }

    /// The same lookup, narrowed to one program. Passing no program searches everything, which is
    /// what every caller did before `previousWorkoutReference` was honoured.
    @Test("Test The Last Session Can Be Narrowed To One Program")
    func testTheLastSessionCanBeNarrowedToOneProgram() async throws {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: [
            session(id: "in-program", templateId: "push", programId: "program-1", daysAgo: 10),
            session(id: "freehand", templateId: "push", daysAgo: 1)
        ])

        let unrestricted = try await manager.getLastCompletedSessionForTemplate(
            templateId: "push",
            authorId: "author-1"
        )
        #expect(unrestricted?.id == "freehand")

        let narrowed = try await manager.getLastCompletedSessionForTemplate(
            templateId: "push",
            authorId: "author-1",
            inTrainingProgramId: "program-1"
        )
        #expect(narrowed?.id == "in-program")
    }

    /// A program with nothing logged in it yet has no previous session, rather than borrowing one
    /// from outside it.
    @Test("Test A Program With No History Has No Last Session")
    func testAProgramWithNoHistoryHasNoLastSession() async throws {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: [
            session(id: "freehand", templateId: "push", daysAgo: 1)
        ])

        let narrowed = try await manager.getLastCompletedSessionForTemplate(
            templateId: "push",
            authorId: "author-1",
            inTrainingProgramId: "program-1"
        )

        #expect(narrowed == nil)
    }

    // MARK: - The any-exercise lookup

    /// What `.anyExercise` means, and what the two template scopes fall back to: the last times
    /// this exercise was performed, whatever workout it happened to be part of.
    @Test("Test The Exercise Lookup Finds Every Workout That Included It")
    func testTheExerciseLookupFindsEveryWorkoutThatIncludedIt() async throws {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: [
            session(id: "push-old", templateId: "push", daysAgo: 10, exerciseTemplateIds: ["bench"]),
            session(id: "chest-recent", templateId: "chest", daysAgo: 1, exerciseTemplateIds: ["bench", "fly"]),
            session(id: "legs", templateId: "legs", daysAgo: 2, exerciseTemplateIds: ["squat"])
        ])

        let found = try await manager.getLastCompletedSessionsContainingExercise(
            exerciseTemplateId: "bench",
            authorId: "author-1"
        )

        #expect(found.map(\.id) == ["chest-recent", "push-old"])
    }

    /// An unfinished workout is not history — its sets are still being typed in.
    @Test("Test The Exercise Lookup Ignores A Session Still In Progress")
    func testTheExerciseLookupIgnoresASessionStillInProgress() async throws {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: [
            session(id: "finished", templateId: "push", daysAgo: 5, exerciseTemplateIds: ["bench"]),
            session(id: "running", templateId: "push", daysAgo: 1, ended: false, exerciseTemplateIds: ["bench"])
        ])

        let found = try await manager.getLastCompletedSessionsContainingExercise(
            exerciseTemplateId: "bench",
            authorId: "author-1"
        )

        #expect(found.map(\.id) == ["finished"])
    }

    @Test("Test The Exercise Lookup Can Be Narrowed To One Program And Limited")
    func testTheExerciseLookupCanBeNarrowedToOneProgramAndLimited() async throws {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: [
            session(id: "in-program-old", templateId: "push", programId: "program-1", daysAgo: 10, exerciseTemplateIds: ["bench"]),
            session(id: "in-program-new", templateId: "chest", programId: "program-1", daysAgo: 2, exerciseTemplateIds: ["bench"]),
            session(id: "freehand", templateId: "push", daysAgo: 1, exerciseTemplateIds: ["bench"])
        ])

        let narrowed = try await manager.getLastCompletedSessionsContainingExercise(
            exerciseTemplateId: "bench",
            authorId: "author-1",
            inTrainingProgramId: "program-1"
        )
        #expect(narrowed.map(\.id) == ["in-program-new", "in-program-old"])

        let limited = try await manager.getLastCompletedSessionsContainingExercise(
            exerciseTemplateId: "bench",
            authorId: "author-1",
            limit: 2
        )
        #expect(limited.map(\.id) == ["freehand", "in-program-new"])
    }

    @Test("Test An Exercise Never Performed Has No Sessions")
    func testAnExerciseNeverPerformedHasNoSessions() async throws {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: [
            session(id: "push", templateId: "push", daysAgo: 1, exerciseTemplateIds: ["bench"])
        ])

        let found = try await manager.getLastCompletedSessionsContainingExercise(
            exerciseTemplateId: "deadlift",
            authorId: "author-1"
        )

        #expect(found.isEmpty)
    }

    // MARK: - Writing

    @Test("Test Saving A Session Adds It To The History")
    func testSavingASessionAddsItToTheHistory() async throws {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: [])

        try await manager.saveWorkoutSession(session(id: "new"))

        let added = await TestManagers.eventually { manager.workoutSessions.map(\.id) == ["new"] }
        #expect(added)
    }

    @Test("Test Deleting A Session Removes It")
    func testDeletingASessionRemovesIt() async throws {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: history)

        try await manager.deleteWorkoutSession(id: "s2")

        let removed = await TestManagers.eventually { manager.workoutSessions.count == 2 }
        #expect(removed)
        #expect(!manager.workoutSessions.map(\.id).contains("s2"))
    }

    // MARK: - The session in progress

    /// A workout being tracked is not history yet, so it must not show up among the logged ones.
    @Test("Test There Is No Active Session To Begin With")
    func testThereIsNoActiveSessionToBeginWith() async {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: history)

        #expect(manager.activeSession == nil)
        #expect(manager.workoutSessions.count == 3)
    }

    @Test("Test An Active Session Is Held Apart From The History")
    func testAnActiveSessionIsHeldApartFromTheHistory() async throws {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: [])

        try manager.updateActiveSession(session(id: "live", ended: false))

        #expect(manager.activeSession?.id == "live")
        #expect(manager.workoutSessions.isEmpty)
    }

    @Test("Test Updating The Active Session Replaces It")
    func testUpdatingTheActiveSessionReplacesIt() async throws {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: [])
        try manager.updateActiveSession(session(id: "live", ended: false))

        var updated = session(id: "live", ended: false)
        updated.updateDuration(1800)
        try manager.updateActiveSession(updated)

        #expect(manager.activeSession?.endedAt != nil)
    }

    @Test("Test Abandoning The Active Session Clears It")
    func testAbandoningTheActiveSessionClearsIt() async throws {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: [])
        try manager.updateActiveSession(session(id: "live", ended: false))
        #expect(manager.activeSession != nil)

        try manager.deleteActiveSession()

        #expect(manager.activeSession == nil)
        #expect(manager.workoutSessions.isEmpty)
    }

    /// Finishing a workout moves it from the one-in-progress slot into the history.
    @Test("Test Ending A Session Moves It Into The History")
    func testEndingASessionMovesItIntoTheHistory() async throws {
        let manager = await TestManagers.signedInWorkoutSessionManager(sessions: [])
        try manager.updateActiveSession(session(id: "live", ended: false))

        try await manager.endWorkoutSession(session(id: "live"))

        let logged = await TestManagers.eventually { manager.workoutSessions.map(\.id) == ["live"] }
        #expect(logged)
        #expect(manager.activeSession == nil)
    }
}
