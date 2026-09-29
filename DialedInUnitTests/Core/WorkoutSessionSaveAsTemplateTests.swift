//
//  WorkoutSessionSaveAsTemplateTests.swift
//  DialedInUnitTests
//
//  The feed card's "Save as Template" action: it saves through the manager and offers to open the
//  result, or says why it could not.
//

import Testing
import SwiftUI
@testable import DialedIn

@MainActor
struct WorkoutSessionSaveAsTemplateTests {

    private typealias Fixture = SaveTemplateFixture

    private final class Interactor: SpyGlobalInteractor, WorkoutSessionRowInteractor {
        var currentUser: UserModel? = UserModel(userId: "me")
        var allExercises: [ExerciseModel] = []
        var allWorkoutTemplates: [WorkoutTemplateModel] = []
        var saveError: Error?
        private(set) var saved: [WorkoutTemplateModel] = []

        func workoutSessions(authoredBy authorId: String) -> [WorkoutSessionModel] { [] }
        func likeSession(sessionId: String, authorId: String, userId: String) async throws { }
        func unlikeSession(sessionId: String, authorId: String, userId: String) async throws { }
        func report(contentType: ReportContentType, contentId: String, authorUserId: String?, reason: ReportReason, notes: String?) async throws { }

        func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws {
            if let saveError { throw saveError }
            saved.append(workoutTemplate)
        }
    }

    private final class Router: WorkoutSessionRowRouter {
        func showShareToFollowerView(delegate: ShareToFollowerDelegate) { }
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []
        private(set) var alertsWithButtons: [String] = []
        private(set) var openedTemplateIds: [String] = []

        func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) { }
        func showSocialProfileView(delegate: SocialProfileDelegate) { }
        func showCommentsView(delegate: CommentsDelegate) { }
        func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate) { openedTemplateIds.append(delegate.workoutTemplate.id) }

        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            alertTitles.append(title)
            if buttons != nil { alertsWithButtons.append(title) }
        }

        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    private struct Row {
        let presenter: WorkoutSessionRowPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeRow(library: [ExerciseModel], existing: [WorkoutTemplateModel] = []) -> Row {
        let interactor = Interactor()
        interactor.allExercises = library
        interactor.allWorkoutTemplates = existing
        let router = Router()
        let session = Fixture.session(exercises: [
            Fixture.logged("Bench Press", templateId: "bench", index: 1),
            Fixture.logged("Mystery Lift", templateId: "friend-only", index: 2)
        ])
        let presenter = WorkoutSessionRowPresenter(
            interactor: interactor,
            router: router,
            delegate: WorkoutSessionRowDelegate(session: session, author: UserModel(userId: "friend"))
        )
        return Row(presenter: presenter, interactor: interactor, router: router)
    }

    @Test("Test A Successful Save Calls The Manager And Offers Open")
    func testASuccessfulSaveCallsTheManagerAndOffersOpen() async {
        let row = makeRow(library: [Fixture.libraryExercise(id: "bench", name: "Bench Press")])
        let presenter = row.presenter, interactor = row.interactor, router = row.router

        presenter.onSaveAsTemplatePressed()
        await TestManagers.eventually { !router.alertTitles.isEmpty }

        let saved = interactor.saved.first
        #expect(interactor.saved.count == 1)
        #expect(saved?.authorId == "me")
        #expect(saved?.exercises.map { $0.exercise.id } == ["bench"])
        #expect(router.alertsWithButtons == ["Saved to your workouts"])
        #expect(interactor.trackedEventNames.contains("WorkoutSessionRow_SaveAsTemplate_Success"))

        guard let saved else { return }
        presenter.onOpenSavedTemplatePressed(saved)
        #expect(router.openedTemplateIds == [saved.id])
    }

    @Test("Test Saving A Name The Reader Already Has Adds Copy")
    func testSavingANameTheReaderAlreadyHasAddsCopy() async {
        let existing = WorkoutTemplateModel(authorId: "me", name: "Push Day")
        let row = makeRow(library: [Fixture.libraryExercise(id: "bench", name: "Bench Press")], existing: [existing])
        let presenter = row.presenter, interactor = row.interactor

        presenter.onSaveAsTemplatePressed()
        await TestManagers.eventually { !interactor.saved.isEmpty }

        #expect(interactor.saved.first?.name == "Push Day (copy)")
    }

    @Test("Test An Unresolvable Session Saves Nothing And Alerts")
    func testAnUnresolvableSessionSavesNothingAndAlerts() {
        let row = makeRow(library: [Fixture.libraryExercise(id: "squat", name: "Squat")])
        let presenter = row.presenter, interactor = row.interactor, router = row.router

        presenter.onSaveAsTemplatePressed()

        #expect(interactor.saved.isEmpty)
        #expect(router.alertTitles == ["None of these exercises are in your library"])
        #expect(interactor.trackedEventNames.contains("WorkoutSessionRow_SaveAsTemplate_Unresolved"))
    }

    @Test("Test A Failed Save Says So")
    func testAFailedSaveSaysSo() async {
        let row = makeRow(library: [Fixture.libraryExercise(id: "bench", name: "Bench Press")])
        let presenter = row.presenter, interactor = row.interactor, router = row.router
        interactor.saveError = URLError(.notConnectedToInternet)

        presenter.onSaveAsTemplatePressed()
        await TestManagers.eventually { !router.alertTitles.isEmpty }

        #expect(router.alertTitles == ["Unable to Save Workout"])
        #expect(router.alertsWithButtons.isEmpty)
    }
}
