//
//  WorkoutSessionAuthorTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// Who a workout is shown as written by.
///
/// The detail screen's header used to be handed `UserModel.mock`, so every session — the reader's
/// own and a stranger's from the feed alike — was attributed to a fictional user, whose profile
/// opened on a tap. The author is read from the session now, and stays unknown when it cannot be.
@MainActor
struct WorkoutSessionAuthorTests {

    private final class Interactor: SpyGlobalInteractor, WorkoutSessionDetailInteractor {
        var currentUser: UserModel?
        var users: [String: UserModel] = [:]
        private(set) var userLookups: [String] = []

        func getUser(userId: String) async throws -> UserModel {
            userLookups.append(userId)
            guard let user = users[userId] else { throw URLError(.fileDoesNotExist) }
            return user
        }

        func saveWorkoutSession(_ session: WorkoutSessionModel) async throws { }
        func getPreference(templateId: String) -> ExerciseUnitPreference {
            ExerciseUnitPreference(exerciseModelId: templateId)
        }
        func setPreference(weightUnit: ExerciseWeightUnit?, distanceUnit: ExerciseDistanceUnit?, for templateId: String) { }
        func deleteWorkoutSession(id: String) async throws { }
        func workoutSessions(authoredBy authorId: String) -> [WorkoutSessionModel] { [] }
    }

    private final class Router: WorkoutSessionDetailRouter {
        let router: AnyRouter = TestRouting.anyRouter

        // Unguarded on purpose: the test target has no `-DDEV`, so a `#if DEV || MOCK` stub
        // disappears while the protocol requirement stays.
        func showDevSettingsView() { }
        func showExercisesPickerView(delegate: ExercisesPickerDelegate) { }
    }

    private struct Screen {
        let presenter: WorkoutSessionDetailPresenter
        let interactor: Interactor
    }

    private func makeScreen(user: UserModel?) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = user
        return Screen(
            presenter: WorkoutSessionDetailPresenter(interactor: interactor, router: Router()),
            interactor: interactor
        )
    }

    private var session: WorkoutSessionModel {
        WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Push Day",
            dateCreated: Date(timeIntervalSince1970: 1_000_000),
            exercises: []
        )
    }

    @Test("Test The Author Is The User Who Logged The Workout")
    func testTheAuthorIsTheUserWhoLoggedTheWorkout() async {
        let screen = makeScreen(user: UserModel(userId: "reader-1"))
        screen.interactor.users["author-1"] = UserModel(userId: "author-1", firstName: "Alex")

        await screen.presenter.loadAuthor(for: session)

        #expect(screen.presenter.author?.userId == "author-1")
        #expect(screen.interactor.userLookups == ["author-1"])
    }

    /// Their own workout needs no lookup — the signed-in user is already to hand.
    @Test("Test Your Own Workout Reads The Author You Already Have")
    func testYourOwnWorkoutReadsTheAuthorYouAlreadyHave() async {
        let screen = makeScreen(user: UserModel(userId: "author-1", firstName: "Alex"))

        await screen.presenter.loadAuthor(for: session)

        #expect(screen.presenter.author?.userId == "author-1")
        #expect(screen.interactor.userLookups.isEmpty)
    }

    /// An author who cannot be read stays unknown, so no name is shown rather than the wrong one.
    @Test("Test An Unreadable Author Stays Unknown")
    func testAnUnreadableAuthorStaysUnknown() async {
        let screen = makeScreen(user: UserModel(userId: "reader-1"))

        await screen.presenter.loadAuthor(for: session)

        #expect(screen.presenter.author == nil)
    }
}
