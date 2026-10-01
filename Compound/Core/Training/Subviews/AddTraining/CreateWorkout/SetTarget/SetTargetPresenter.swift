import SwiftUI

@Observable
@MainActor
class SetTargetPresenter {
    
    private let interactor: SetTargetInteractor
    private let router: SetTargetRouter

    /// The parent's exercise, written only on confirm.
    private let committedExercise: Binding<WorkoutTemplateExercise>
    private let initialExercise: WorkoutTemplateExercise

    /// The working copy the screen edits.
    var workingExercise: WorkoutTemplateExercise

    /// Swiping the sheet down used to drop typed targets without a word; the view blocks the swipe
    /// on this, and close asks.
    var hasUnsavedChanges: Bool {
        workingExercise != initialExercise
    }

    init(interactor: SetTargetInteractor, router: SetTargetRouter, delegate: SetTargetDelegate) {
        self.interactor = interactor
        self.router = router
        self.committedExercise = delegate.exercise
        self.initialExercise = delegate.exercise.wrappedValue
        self.workingExercise = delegate.exercise.wrappedValue
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onAddSetPressed() {
        workingExercise.setTargets.append(SetTarget(setNumber: workingExercise.setTargets.count + 1))
    }

    func onDeleteSetPressed(_ setTarget: SetTarget) {
        workingExercise.setTargets.removeAll { $0.id == setTarget.id }
        for index in workingExercise.setTargets.indices {
            workingExercise.setTargets[index].setNumber = index + 1
        }
    }

    func onClosePressed() {
        guard hasUnsavedChanges else {
            router.dismissScreen()
            return
        }
        router.showDiscardChangesDialog { [weak self] in
            Task { @MainActor in self?.router.dismissScreen() }
        }
    }

    /// A minimum typed above its maximum saved as "12–8 reps". The two are swapped instead, which
    /// is what was meant.
    func onSavePressed() {
        var exercise = workingExercise
        for index in exercise.setTargets.indices {
            if let min = exercise.setTargets[index].minReps, let max = exercise.setTargets[index].maxReps, min > max {
                exercise.setTargets[index].minReps = max
                exercise.setTargets[index].maxReps = min
            }
        }
        committedExercise.wrappedValue = exercise
        router.dismissScreen()
    }
    
}

extension SetTargetPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "SetTargetView_Appear"
            case .onDisappear: return "SetTargetView_Disappear"
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
