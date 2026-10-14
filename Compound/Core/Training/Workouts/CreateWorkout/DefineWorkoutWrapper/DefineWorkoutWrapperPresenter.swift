import SwiftUI

@Observable
@MainActor
class DefineWorkoutWrapperPresenter {
    
    private let interactor: DefineWorkoutWrapperInteractor
    private let router: DefineWorkoutWrapperRouter
    
    /// Backing out to change the name or gym used to throw the whole exercise list away. Every
    /// change is written through to the name step's draft, which outlives this screen.
    var exercises: [WorkoutTemplateExercise] {
        didSet { draft?.wrappedValue = exercises }
    }
    private let draft: Binding<[WorkoutTemplateExercise]>?
    private(set) var isSaving: Bool = false

    var currentUser: UserModel? {
        interactor.currentUser
    }

    /// An empty template starts a workout with nothing to do, and a second tap mid-save wrote it twice.
    var canSave: Bool {
        !exercises.isEmpty && !isSaving
    }
    
    init(
        interactor: DefineWorkoutWrapperInteractor,
        router: DefineWorkoutWrapperRouter,
        exercises: [WorkoutTemplateExercise] = [],
        draft: Binding<[WorkoutTemplateExercise]>? = nil
    ) {
        self.interactor = interactor
        self.router = router
        self.draft = draft
        self.exercises = draft?.wrappedValue ?? exercises
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
    
    func onConfirmPressed(delegate: DefineWorkoutWrapperDelegate) {
        guard canSave else { return }
        // Reachable: the user document arrives on the sync engine's own task. A silent return threw
        // the whole wizard away.
        guard let uid = currentUser?.userId else {
            interactor.playHaptic(option: .error)
            router.showSimpleAlert(title: String(localized: "Unable to Save Workout"), subtitle: String(localized: "Please try again."))
            return
        }
        let existing = delegate.workoutTemplate
        let workout = WorkoutTemplateModel(
            id: existing?.id ?? UUID().uuidString,
            authorId: existing?.authorId ?? uid,
            name: delegate.name,
            description: existing?.description,
            gymProfileId: delegate.gymProfile.id,
            imageURL: existing?.imageURL,
            dateCreated: existing?.dateCreated ?? Date.now,
            dateModified: Date.now,
            exercises: exercises
        )

        // Dismissing before the save returned tore the failure alert down with the screen.
        // The flag is raised here, not in the task, so a second tap on the same tick is refused.
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            interactor.trackEvent(event: Event.saveWorkoutStart(isNew: existing == nil))
            do {
                try await interactor.saveWorkoutTemplate(workoutTemplate: workout, image: nil)
                interactor.trackEvent(event: Event.saveWorkoutSuccess(isNew: existing == nil))
                interactor.playHaptic(option: .success)
                router.dismissEnvironment()
            } catch {
                interactor.trackEvent(event: Event.saveWorkoutFail(error: error))
                interactor.playHaptic(option: .error)
                router.showSimpleAlert(title: String(localized: "Unable to Save Workout"), subtitle: String(localized: "Please try again."))
            }
        }
    }

}

extension DefineWorkoutWrapperPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case saveWorkoutStart(isNew: Bool)
        case saveWorkoutSuccess(isNew: Bool)
        case saveWorkoutFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear: return "DefineWorkoutWrapperView_Appear"
            case .onDisappear: return "DefineWorkoutWrapperView_Disappear"
            case .saveWorkoutStart: return "DefineWorkoutWrapperView_SaveWorkout_Start"
            case .saveWorkoutSuccess: return "DefineWorkoutWrapperView_SaveWorkout_Success"
            case .saveWorkoutFail: return "DefineWorkoutWrapperView_SaveWorkout_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .saveWorkoutStart(let isNew), .saveWorkoutSuccess(let isNew):
                return ["is_new": isNew]
            case .saveWorkoutFail(let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .saveWorkoutFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
