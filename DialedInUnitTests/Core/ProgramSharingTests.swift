//
//  ProgramSharingTests.swift
//  DialedInUnitTests
//

import Testing
import SwiftUI
@testable import DialedIn

/// Sharing a template or program with a mutual, and the recipient copying it into their library.
@MainActor
struct ProgramSharingTests {

    private enum SharingTestError: Error { case failed }

    // MARK: Doubles

    private final class Router: ShareToFollowerRouter, SharedItemRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []

        func showAlert(error: Error) { alertTitles.append("error") }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    private final class PickerInteractor: SpyGlobalInteractor, ShareToFollowerInteractor {
        var currentUser: UserModel?
        var followingUsers: [UserModel] = []
        var sendError: Error?
        private(set) var sent: [(name: String, ids: [String])] = []

        func sendShare(_ payload: ShareModel.Payload, to userIds: [String]) async throws {
            if let sendError { throw sendError }
            sent.append((payload.name, userIds))
        }
    }

    private final class ItemInteractor: SpyGlobalInteractor, SharedItemInteractor {
        var userId: String? = "me"
        var allExercises: [ExerciseModel] = []
        var saveError: Error?
        private(set) var savedExercises: [ExerciseModel] = []
        private(set) var savedTemplates: [WorkoutTemplateModel] = []
        private(set) var savedPrograms: [TrainingProgram] = []
        private(set) var statusUpdates: [String] = []

        func saveExerciseModel(exercise: ExerciseModel, image: PlatformImage?) async throws {
            if let saveError { throw saveError }
            savedExercises.append(exercise)
        }

        func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws {
            if let saveError { throw saveError }
            savedTemplates.append(workoutTemplate)
        }

        func saveTrainingProgram(trainingProgram: TrainingProgram) async throws {
            if let saveError { throw saveError }
            savedPrograms.append(trainingProgram)
        }

        func updateShareStatus(_ status: ShareModel.Status, id: String) async throws {
            statusUpdates.append("\(status.rawValue):\(id)")
        }
    }

    // MARK: Fixtures

    private let systemExercise: ExerciseModel = {
        var exercise = ExerciseModel.mocks[0]
        exercise.id = "system-bench"
        exercise.isSystemExercise = true
        return exercise
    }()

    private let customExercise: ExerciseModel = {
        var exercise = ExerciseModel.mocks[1]
        exercise.id = "alice-custom"
        exercise.authorId = "alice"
        exercise.isSystemExercise = false
        return exercise
    }()

    private func template(id: String = "alice-template") -> WorkoutTemplateModel {
        WorkoutTemplateModel(
            id: id,
            authorId: "alice",
            name: "Push Day",
            gymProfileId: "alice-gym",
            exercises: [
                WorkoutTemplateExercise(exercise: systemExercise, setRestTimers: false),
                WorkoutTemplateExercise(exercise: customExercise, setRestTimers: false),
                WorkoutTemplateExercise(exercise: customExercise, setRestTimers: false)
            ]
        )
    }

    private struct ItemScreen {
        let presenter: SharedItemPresenter
        let interactor: ItemInteractor
        let router: Router
    }

    private func itemScreen(_ payload: ShareModel.Payload) -> ItemScreen {
        let interactor = ItemInteractor()
        interactor.allExercises = [systemExercise]
        let router = Router()
        let share = ShareModel(id: "share-1", fromUserId: "alice", toUserId: "me", payload: payload)
        let presenter = SharedItemPresenter(interactor: interactor, router: router, delegate: SharedItemDelegate(share: share, senderName: "Alice"))
        return ItemScreen(presenter: presenter, interactor: interactor, router: router)
    }

    // MARK: Picker

    @Test("Test The Picker Lists Only Unblocked Mutuals")
    func testThePickerListsOnlyUnblockedMutuals() {
        let interactor = PickerInteractor()
        interactor.currentUser = UserModel(userId: "me", blockedUserIds: ["blocked"])
        interactor.followingUsers = [
            UserModel(userId: "mutual", followingIds: ["me"]),
            UserModel(userId: "oneway", followingIds: ["someone"]),
            UserModel(userId: "blocked", followingIds: ["me"])
        ]
        let presenter = ShareToFollowerPresenter(interactor: interactor, router: Router(), delegate: ShareToFollowerDelegate(payload: .template(template())))

        #expect(presenter.recipients.map(\.userId) == ["mutual"])
    }

    @Test("Test Offline Send Says You're Offline And Sends Nothing")
    func testOfflineSendSaysYoureOfflineAndSendsNothing() async {
        let interactor = PickerInteractor()
        interactor.currentUser = UserModel(userId: "me")
        interactor.followingUsers = [UserModel(userId: "amy", followingIds: ["me"])]
        interactor.isOffline = true
        let router = Router()
        let presenter = ShareToFollowerPresenter(interactor: interactor, router: router, delegate: ShareToFollowerDelegate(payload: .template(template())))

        presenter.onRecipientPressed(interactor.followingUsers[0])
        presenter.onSendPressed()

        #expect(router.alertTitles == [OfflineError.title])
        #expect(!presenter.isSending)
        #expect(interactor.sent.isEmpty)
    }

    @Test("Test Send Goes To Each Selected Recipient In List Order")
    func testSendGoesToEachSelectedRecipientInListOrder() async {
        let interactor = PickerInteractor()
        interactor.currentUser = UserModel(userId: "me")
        interactor.followingUsers = ["amy", "bob", "cal"].map { UserModel(userId: $0, followingIds: ["me"]) }
        let presenter = ShareToFollowerPresenter(interactor: interactor, router: Router(), delegate: ShareToFollowerDelegate(payload: .template(template())))

        #expect(!presenter.canSend)
        presenter.onRecipientPressed(interactor.followingUsers[2])
        presenter.onRecipientPressed(interactor.followingUsers[1])
        presenter.onRecipientPressed(interactor.followingUsers[0])
        presenter.onRecipientPressed(interactor.followingUsers[1])
        presenter.onSendPressed()
        await TestManagers.eventually { !interactor.sent.isEmpty }

        #expect(interactor.sent.count == 1)
        #expect(interactor.sent.first?.name == "Push Day")
        #expect(interactor.sent.first?.ids == ["amy", "cal"])
        #expect(interactor.trackedEventNames.contains("ShareToFollowerView_Send_Success"))
    }

    @Test("Test A Failed Send Alerts And Can Be Retried")
    func testAFailedSendAlertsAndCanBeRetried() async {
        let interactor = PickerInteractor()
        interactor.currentUser = UserModel(userId: "me")
        interactor.followingUsers = [UserModel(userId: "amy", followingIds: ["me"])]
        interactor.sendError = SharingTestError.failed
        let router = Router()
        let presenter = ShareToFollowerPresenter(interactor: interactor, router: router, delegate: ShareToFollowerDelegate(payload: .template(template())))

        presenter.onRecipientPressed(interactor.followingUsers[0])
        presenter.onSendPressed()
        await TestManagers.eventually { !router.alertTitles.isEmpty }

        #expect(router.alertTitles == ["Unable to share"])
        #expect(presenter.canSend)
    }

    // MARK: Accept

    @Test("Test Accepting A Template Copies It Under The Recipient With New Ids")
    func testAcceptingATemplateCopiesItUnderTheRecipientWithNewIds() async {
        let screen = itemScreen(.template(template()))
        let presenter = screen.presenter, interactor = screen.interactor

        presenter.onAddToLibraryPressed()
        await TestManagers.eventually { !interactor.statusUpdates.isEmpty }

        let copy = interactor.savedTemplates.first
        #expect(interactor.savedTemplates.count == 1)
        #expect(copy?.id != "alice-template")
        #expect(copy?.authorId == "me")
        #expect(copy?.gymProfileId == nil)
        // The seeded exercise keeps its id; the sender's custom one is copied once, as the recipient's.
        #expect(interactor.savedExercises.count == 1)
        let newExercise = interactor.savedExercises.first
        #expect(newExercise?.id != "alice-custom")
        #expect(newExercise?.authorId == "me")
        let newId = newExercise?.id ?? "missing"
        #expect(copy?.exercises.map(\.exercise.id) == ["system-bench", newId, newId])
        #expect(interactor.statusUpdates == ["accepted:share-1"])
        #expect(presenter.status == .accepted)
    }

    @Test("Test Accepting A Program Copies Every Day")
    func testAcceptingAProgramCopiesEveryDay() async {
        let program = TrainingProgram(
            id: "alice-program",
            authorId: "alice",
            name: "Block",
            icon: "flag",
            colour: "#FF0000",
            workoutTemplates: [template(id: "day-1"), template(id: "day-2")]
        )
        let screen = itemScreen(.program(program))
        let presenter = screen.presenter, interactor = screen.interactor

        presenter.onAddToLibraryPressed()
        await TestManagers.eventually { !interactor.statusUpdates.isEmpty }

        let copy = interactor.savedPrograms.first
        #expect(copy?.id != "alice-program")
        #expect(copy?.authorId == "me")
        #expect(copy?.workoutTemplates.count == 2)
        #expect(copy?.workoutTemplates.contains { ["day-1", "day-2"].contains($0.id) || $0.authorId != "me" } == false)
        #expect(interactor.savedExercises.count == 1)
        #expect(interactor.statusUpdates == ["accepted:share-1"])
    }

    @Test("Test A Failed Copy Leaves The Share Pending")
    func testAFailedCopyLeavesTheSharePending() async {
        let screen = itemScreen(.template(template()))
        let presenter = screen.presenter, interactor = screen.interactor, router = screen.router
        interactor.saveError = SharingTestError.failed

        presenter.onAddToLibraryPressed()
        await TestManagers.eventually { !router.alertTitles.isEmpty }

        #expect(router.alertTitles == ["Unable to add"])
        #expect(interactor.statusUpdates.isEmpty)
        #expect(presenter.status == .pending)
    }

    @Test("Test Dismissing Marks The Share And Saves Nothing")
    func testDismissingMarksTheShareAndSavesNothing() async {
        let screen = itemScreen(.template(template()))
        let presenter = screen.presenter, interactor = screen.interactor

        presenter.onDismissSharePressed()
        await TestManagers.eventually { !interactor.statusUpdates.isEmpty }

        #expect(interactor.statusUpdates == ["dismissed:share-1"])
        #expect(interactor.savedTemplates.isEmpty)
        #expect(interactor.savedExercises.isEmpty)
    }

    // MARK: Model

    @Test("Test A Share Round Trips Its Kind And Payload")
    func testAShareRoundTripsItsKindAndPayload() throws {
        let share = ShareModel(id: "s", fromUserId: "a", toUserId: "b", payload: .program(.mock), dateCreated: Date(timeIntervalSince1970: 0))
        let data = try JSONEncoder().encode(share)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let decoded = try JSONDecoder().decode(ShareModel.self, from: data)

        #expect(json?["kind"] as? String == "program")
        #expect(json?["from_user_id"] as? String == "a")
        #expect(decoded.payload.name == TrainingProgram.mock.name)
        #expect(decoded.status == .pending)
        #expect(PrivateUserSettings.socialPushKey(for: .share).rawValue == "social_push_shares")
        #expect(PrivateUserSettings().isSocialPushEnabled(for: .share))
    }
}
