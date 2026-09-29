//
//  WorkoutSessionDeleteFailureTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The detail screen used to dismiss first and `try?` the delete, so a refused delete vanished
/// from view with no alert and came back later. It now stays and says so, once.
@MainActor
struct WorkoutSessionDeleteFailureTests {

    private final class Interactor: SpyGlobalInteractor, WorkoutSessionDetailInteractor {
        var currentUser: UserModel? = UserModel(userId: "author-1")

        func getUser(userId: String) async throws -> UserModel { throw URLError(.fileDoesNotExist) }
        func saveWorkoutSession(_ session: WorkoutSessionModel) async throws { }
        func getPreference(templateId: String) -> ExerciseUnitPreference {
            ExerciseUnitPreference(exerciseModelId: templateId)
        }
        func setPreference(weightUnit: ExerciseWeightUnit?, distanceUnit: ExerciseDistanceUnit?, for templateId: String) { }
        func deleteWorkoutSession(id: String) async throws { throw URLError(.notConnectedToInternet) }
        func workoutSessions(authoredBy authorId: String) -> [WorkoutSessionModel] { [] }
    }

    private final class Router: WorkoutSessionDetailRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []

        func showDevSettingsView() { }
        func showExercisesPickerView(delegate: ExercisesPickerDelegate) { }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    @Test("Test A Failed Delete Alerts Once")
    func testAFailedDeleteAlertsOnce() async {
        let interactor = Interactor()
        let router = Router()
        let presenter = WorkoutSessionDetailPresenter(interactor: interactor, router: router)

        presenter.deleteSession(session: WorkoutSessionModel(id: "session-1", authorId: "author-1", name: "Push Day", dateCreated: Date(), exercises: []))

        #expect(await TestManagers.eventually(timeout: .seconds(5)) { !router.alertTitles.isEmpty })
        for _ in 0..<10 { await Task.yield() }
        #expect(router.alertTitles == ["Unable to Delete Workout"])
        #expect(interactor.trackedEventNames == ["WorkoutSessionDetailView_DeleteSession_Fail"])
    }
}
