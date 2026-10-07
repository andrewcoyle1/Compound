import SwiftUI

@Observable
@MainActor
class SetTargetPresenter {
    
    let interactor: SetTargetInteractor
    let router: SetTargetRouter

    /// The parent's exercise, written only on confirm.
    private let committedExercise: Binding<WorkoutTemplateExercise>
    private let initialExercise: WorkoutTemplateExercise

    /// The working copy the screen edits.
    var workingExercise: WorkoutTemplateExercise

    /// What the screen offers beside the targets: the tracker edits a session's targets, a template
    /// exercise also its plan, and a week's variation only its own targets.
    let scope: SetTargetScope

    /// The link as typed. It reaches `workingExercise` only once it is a web address (or empty), so
    /// a half-typed one is never saved.
    var linkText: String {
        didSet { onLinkTextChanged() }
    }
    /// Shown once the link is submitted, or Save is tried, while it is not a web address.
    var showsLinkError = false

    /// Swiping the sheet down used to drop typed targets without a word; the view blocks the swipe
    /// on this, and close asks.
    var hasUnsavedChanges: Bool {
        workingExercise != initialExercise || linkText != (initialExercise.linkURL ?? "")
    }

    init(interactor: SetTargetInteractor, router: SetTargetRouter, delegate: SetTargetDelegate) {
        self.interactor = interactor
        self.router = router
        self.committedExercise = delegate.exercise
        self.initialExercise = delegate.exercise.wrappedValue
        self.workingExercise = delegate.exercise.wrappedValue
        self.scope = delegate.scope
        self.linkText = delegate.exercise.wrappedValue.linkURL ?? ""
        self.settings = interactor.workoutSettings
    }

    /// "Targets", or "From week 3" for a week's variation.
    var title: String {
        if case .week(let week) = scope { return String(localized: "From week \(week)") }
        return String(localized: "Targets")
    }

    var showsPlan: Bool { scope == .template }

    /// A week's variation carries targets only; the rest timers belong to the exercise.
    var showsRestTimers: Bool {
        if case .week = scope { return false }
        return true
    }

    // MARK: - Set plan (Workout Settings › Set Plan)

    private let settings: WorkoutSettings

    /// Off, the editor is exactly as it was before the set plan: no kinds, no line under a set.
    var plansSets: Bool { settings.plansSets }

    func planTitle(for setTarget: SetTarget) -> String {
        SetTargetPlan.title(for: setTarget.setType)
    }

    func planChip(for setTarget: SetTarget) -> String? {
        SetTargetPlan.chip(for: setTarget)
    }

    func planSummary(for setTarget: SetTarget) -> String? {
        SetTargetPlan.summary(for: setTarget, settings: settings)
    }

    /// "Set 3, set type, Drop set".
    func planAccessibilityLabel(for setTarget: SetTarget) -> String {
        String(localized: "Set \(setTarget.setNumber), set type, \(planTitle(for: setTarget))")
    }

    func onSetPlanPressed(_ setTarget: SetTarget) {
        router.showSetPlanDetailView(delegate: SetPlanDetailDelegate(setTarget: setTarget) { [weak self] changed in
            self?.onSetPlanChanged(changed)
        })
    }

    /// The detail sheet's edits land in the working copy, so Save keeps them and Cancel asks first.
    func onSetPlanChanged(_ setTarget: SetTarget) {
        guard let index = workingExercise.setTargets.firstIndex(where: { $0.id == setTarget.id }) else { return }
        workingExercise.setTargets[index] = setTarget
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
    /// is what was meant. A link that is not a web address is not saved: the screen stays, and says
    /// why.
    func onSavePressed() {
        guard linkIsValid else {
            showsLinkError = true
            interactor.playHaptic(option: .error)
            return
        }
        var exercise = workingExercise
        for index in exercise.setTargets.indices {
            if let min = exercise.setTargets[index].minReps, let max = exercise.setTargets[index].maxReps, min > max {
                exercise.setTargets[index].minReps = max
                exercise.setTargets[index].maxReps = min
            }
        }
        let notes = exercise.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        exercise.notes = notes.isEmpty ? nil : notes
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
