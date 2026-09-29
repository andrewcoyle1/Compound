import SwiftUI

@Observable
@MainActor
class DefineWorkoutWrapperPresenter {
    
    private let interactor: DefineWorkoutWrapperInteractor
    private let router: DefineWorkoutWrapperRouter
    
    var exercises: [WorkoutTemplateExercise]
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
        exercises: [WorkoutTemplateExercise] = []
    ) {
        self.interactor = interactor
        self.router = router
        self.exercises = exercises
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
            do {
                try await interactor.saveWorkoutTemplate(workoutTemplate: workout, image: nil)
                router.dismissEnvironment()
            } catch {
                router.showSimpleAlert(title: String(localized: "Unable to Save Workout"), subtitle: String(localized: "Please try again."))
            }
        }
    }

}

extension DefineWorkoutWrapperPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "DefineWorkoutWrapperView_Appear"
            case .onDisappear: return "DefineWorkoutWrapperView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }
}
