import SwiftUI

@Observable
@MainActor
class MesocycleDesignPresenter {
    
    private let interactor: MesocycleDesignInteractor
    private let router: MesocycleDesignRouter
    
    var userId: String {
        interactor.userId ?? ""
    }
    
    var favouriteGymProfile: GymProfileModel? {
        interactor.favouriteGymProfile
    }
    
    var mesocycle: Mesocycle
    private(set) var isSaving: Bool = false

    /// The mesocycle as the screen opened it, to tell an edit from a look.
    private let initialMesocycle: Mesocycle

    /// Close used to ask "discard your changes?" even when nothing had changed, and the swipe on
    /// the edit sheet dropped real changes without asking. Both now follow this.
    /// `Mesocycle` is not `Equatable`, so the fields the screen edits are compared one by one.
    var hasUnsavedChanges: Bool {
        mesocycle.name != initialMesocycle.name
            || mesocycle.icon != initialMesocycle.icon
            || mesocycle.colour != initialMesocycle.colour
            || mesocycle.numMicrocycles != initialMesocycle.numMicrocycles
            || mesocycle.deload != initialMesocycle.deload
            || mesocycle.periodisation != initialMesocycle.periodisation
            || mesocycle.workoutTemplates != initialMesocycle.workoutTemplates
    }

    /// A mesocycle of rest days alone has nothing to activate, and a second tap mid-save wrote twice.
    var canSave: Bool {
        !isSaving && dayPlans.contains { !$0.exercises.isEmpty }
    }
    
    /// The mesocycle's days, read and written straight through to `mesocycle.workoutTemplates`.
    ///
    /// This used to be a second array holding its own copy of the days. The mesocycle settings
    /// sheet edits the mesocycle through a `Binding`, so reordering the days there changed
    /// `mesocycle.workoutTemplates` while this copy kept the old order — the day tabs carried on
    /// showing the old order, and the next edit on this screen wrote the stale copy back over
    /// the reorder. One array cannot drift from itself.
    var dayPlans: [WorkoutTemplateModel] {
        get { mesocycle.workoutTemplates }
        set { mesocycle.workoutTemplates = newValue }
    }
    
    var selectedWorkoutTemplateModel: WorkoutTemplateModel
    
    var selectedWorkoutTemplateModelExercises: Binding<[WorkoutTemplateExercise]> {
        Binding(
            get: { self.selectedWorkoutTemplateModel.exercises },
            set: { [weak self] newValue in
                guard let self else { return }
                guard let index = self.dayPlans.firstIndex(where: { $0.id == self.selectedWorkoutTemplateModel.id }) else { return }
                self.dayPlans[index].exercises = newValue
                self.selectedWorkoutTemplateModel = self.dayPlans[index]
                self.recalculateAutoWorkoutTemplateModelNames()
            }
        )
    }
    
    var canRemoveWorkoutTemplateModel: Bool {
        dayPlans.count > 1
    }

    var isMesocycleActive: Bool {
        interactor.activeMesocycle?.id == mesocycle.id
    }
    
    init(interactor: MesocycleDesignInteractor, router: MesocycleDesignRouter, mesocycle: Mesocycle) {
        self.interactor = interactor
        self.router = router

        var mesocycle = mesocycle
        if let firstPlan = mesocycle.workoutTemplates.first {
            self.selectedWorkoutTemplateModel = firstPlan
        } else {
            let restDay = WorkoutTemplateModel(
                id: UUID().uuidString,
                authorId: interactor.userId ?? "",
                name: Self.restDayName,
                exercises: []
            )
            self.selectedWorkoutTemplateModel = restDay
            mesocycle.workoutTemplates = [restDay]
        }
        self.mesocycle = mesocycle
        self.initialMesocycle = mesocycle
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
    
    func onAddDayPressed() {
        let newWorkoutTemplateModel = WorkoutTemplateModel(
            id: UUID().uuidString,
            authorId: userId,
            name: Self.restDayName,
            exercises: []
        )
        dayPlans.append(
            newWorkoutTemplateModel
        )
        selectedWorkoutTemplateModel = newWorkoutTemplateModel
        recalculateAutoWorkoutTemplateModelNames()
    }
    
    func onWorkoutTemplateModelSelected(_ dayPlan: WorkoutTemplateModel) {
        selectedWorkoutTemplateModel = dayPlan
        interactor.playHaptic(option: .selection)
    }
    
    func onRemoveWorkoutTemplateModelPressed() {
        guard canRemoveWorkoutTemplateModel else { return }
        if let index = dayPlans.firstIndex(where: { $0.id == selectedWorkoutTemplateModel.id }) {
            dayPlans.remove(at: index)
            // Safe: canRemoveWorkoutTemplateModel guarantees a plan remains after the removal.
            selectedWorkoutTemplateModel = dayPlans.first!
            recalculateAutoWorkoutTemplateModelNames()
        }
    }
    
    func onRenameWorkoutTemplateModelPressed() {
        let selectedId = selectedWorkoutTemplateModel.id
        router.showRenameWorkoutTemplateModelView(
            delegate: RenameWorkoutTemplateModelDelegate(
                initialName: selectedWorkoutTemplateModel.name,
                onSave: { [weak self] newName in
                    guard let self else { return }
                    guard let index = self.dayPlans.firstIndex(where: { $0.id == selectedId }) else { return }
                    self.dayPlans[index].name = newName
                    self.selectedWorkoutTemplateModel = self.dayPlans[index]
                }
            )
        )
    }
        
    func onMesocycleSettingsPressed(mesocycle: Binding<Mesocycle>) {
        router.showMesocycleSettingsView(mesocycle: mesocycle)
    }
    
    /// A choice that follows the person's own tap, so an action sheet, answered with verbs.
    func onActivatePressed(delegate: MesocycleDesignDelegate) {
        guard canSave else { return }
        router.showConfirmationDialog(
            title: String(localized: "Save Workout Templates?"),
            subtitle: String(localized: "Each workout day can also be saved to your library, to start on its own.")
        ) {
            AnyView(
                VStack {
                    Button("Save Templates") {
                        Task { await self.saveTemplatesAndActivate(delegate: delegate) }
                    }
                    Button("Don't Save") {
                        Task { await self.activateMesocycle(delegate: delegate) }
                    }
                    Button("Cancel", role: .cancel) { }
                }
            )
        }
    }

    /// Saves each workout day as a standalone template, then activates. A failure here
    /// used to be swallowed by an unstructured `Task`, leaving the mesocycle un-activated with
    /// no feedback; now it surfaces and activation is skipped.
    ///
    /// Rest days are skipped: an empty template in the library is nothing anyone would start.
    /// ponytail: sequential saves; a failure part-way leaves the earlier templates saved.
    func saveTemplatesAndActivate(delegate: MesocycleDesignDelegate) async {
        isSaving = true
        defer { isSaving = false }
        interactor.trackEvent(event: Event.saveTemplatesStart)
        do {
            for workoutTemplate in dayPlans where !workoutTemplate.exercises.isEmpty {
                try await interactor.saveWorkoutTemplate(workoutTemplate: workoutTemplate, image: nil)
            }
            interactor.trackEvent(event: Event.saveTemplatesSuccess)
        } catch {
            interactor.trackEvent(event: Event.saveTemplatesFail(error: error))
            interactor.playHaptic(option: .error)
            router.showAlert(title: String(localized: "Unable to Save Templates"), error: error)
            return
        }

        await activateMesocycle(delegate: delegate)
    }

    /// This was declared `async throws` while wrapping its whole body in a nested `Task`, so
    /// it returned immediately and could never throw — the callers' `try await` was a no-op
    /// and the nested task's errors went nowhere. It is now a plain `async` call that handles
    /// its own errors, which is what the alert path already assumed.
    func activateMesocycle(delegate: MesocycleDesignDelegate) async {
        isSaving = true
        defer { isSaving = false }
        interactor.trackEvent(event: Event.activateStart)
        do {
            try await interactor.saveMesocycle(mesocycle: mesocycle)
            try await interactor.setActiveMesocycle(mesocycleId: mesocycle.id)
            interactor.trackEvent(event: Event.activateSuccess)
            interactor.playHaptic(option: .success)
            // Onboarding hands in the closure that resumes it. This screen used to route
            // onboarding itself and never call it, so the closure was carried four screens for nothing.
            if let onComplete = delegate.onComplete {
                onComplete()
            } else {
                router.dismissEnvironment()
            }
        } catch {
            interactor.trackEvent(event: Event.activateFail(error: error))
            interactor.playHaptic(option: .error)
            router.showAlert(title: String(localized: "Unable to Activate Mesocycle"), error: error)
        }
    }

    /// The close button on the edit sheet. It leaves at once when nothing changed and asks first
    /// when something did. The create flow keeps the system back button instead, which steps back to
    /// the icon picker.
    func onClosePressed() {
        guard hasUnsavedChanges else {
            router.dismissEnvironment()
            return
        }
        router.showDiscardChangesDialog { [weak self] in
            Task { @MainActor in self?.router.dismissEnvironment() }
        }
    }

    // MARK: - Editing a saved mesocycle

    /// Share and Delete were reachable only from the library row's touch-and-hold and swipe.
    func onSharePressed() {
        router.showShareToFollowerView(delegate: ShareToFollowerDelegate(payload: .mesocycle(mesocycle)))
    }

    func onDeletePressed() {
        router.showConfirmationDialog(
            title: String(localized: "Delete Mesocycle?"),
            subtitle: String(localized: "“\(mesocycle.name)” will be deleted. This can't be undone.")
        ) {
            AnyView(
                VStack {
                    Button("Delete Mesocycle", role: .destructive) {
                        Task { await self.deleteMesocycle() }
                    }
                    Button("Cancel", role: .cancel) { }
                }
            )
        }
    }

    func deleteMesocycle() async {
        interactor.trackEvent(event: Event.deleteStart)
        do {
            try await interactor.deleteMesocycle(mesocycleId: mesocycle.id)
            interactor.trackEvent(event: Event.deleteSuccess)
            interactor.playHaptic(option: .success)
            router.dismissEnvironment()
        } catch {
            interactor.trackEvent(event: Event.deleteFail(error: error))
            interactor.playHaptic(option: .error)
            router.showAlert(title: String(localized: "Unable to Delete Mesocycle"), error: error)
        }
    }

    func onSavePressed(delegate: MesocycleDesignDelegate) {
        guard canSave else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            interactor.trackEvent(event: Event.saveStart)
            do {
                try await interactor.saveMesocycle(mesocycle: mesocycle)
                interactor.trackEvent(event: Event.saveSuccess)
                interactor.playHaptic(option: .success)
                router.dismissEnvironment()
            } catch {
                interactor.trackEvent(event: Event.saveFail(error: error))
                interactor.playHaptic(option: .error)
                router.showAlert(title: String(localized: "Unable to Save Mesocycle"), error: error)
            }
        }
    }

    private func recalculateAutoWorkoutTemplateModelNames() {
        var plans = dayPlans
        var workoutIndex = 0
        for index in plans.indices {
            let isRestDay = plans[index].exercises.isEmpty
            let desiredName: String
            if isRestDay {
                desiredName = Self.restDayName
            } else {
                desiredName = Self.workoutDayName(letterForWorkoutIndex(workoutIndex))
                workoutIndex += 1
            }
            
            if isDefaultWorkoutTemplateModelName(plans[index].name) {
                plans[index].name = desiredName
            }
        }
        dayPlans = plans
        
        if let selectedIndex = dayPlans.firstIndex(where: { $0.id == selectedWorkoutTemplateModel.id }) {
            selectedWorkoutTemplateModel = dayPlans[selectedIndex]
        }
    }
    
    private func isDefaultWorkoutTemplateModelName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // The English names stay recognised: mesocycles saved before the names were localized carry them.
        if ["Rest", "Rest Day", Self.restDayName].contains(trimmed) {
            return true
        }
        if trimmed.hasPrefix("Workout "), let suffix = trimmed.split(separator: " ").last,
           suffix.count == 1, suffix.first?.isLetter == true {
            return true
        }
        return (0...dayPlans.count).contains { trimmed == Self.workoutDayName(letterForWorkoutIndex($0)) }
    }

    private static var restDayName: String { String(localized: "Rest Day") }

    private static func workoutDayName(_ letter: String) -> String {
        String(localized: "Workout \(letter)", comment: "A mesocycle day's default name; the letter counts the workout days A, B, C.")
    }
    
    private func letterForWorkoutIndex(_ index: Int) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        guard index >= 0 else { return "A" }
        if index < alphabet.count {
            return String(alphabet[index])
        }
        return "\(String(alphabet[index % alphabet.count]))\(index / alphabet.count)"
    }
    
}

extension MesocycleDesignPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case saveTemplatesStart
        case saveTemplatesSuccess
        case saveTemplatesFail(error: Error)
        case activateStart
        case activateSuccess
        case activateFail(error: Error)
        case deleteStart
        case deleteSuccess
        case deleteFail(error: Error)
        case saveStart
        case saveSuccess
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear: return "ProgramDesignView_Appear"
            case .onDisappear: return "ProgramDesignView_Disappear"
            case .saveTemplatesStart: return "ProgramDesignView_SaveTemplates_Start"
            case .saveTemplatesSuccess: return "ProgramDesignView_SaveTemplates_Success"
            case .saveTemplatesFail: return "ProgramDesignView_SaveTemplates_Fail"
            case .activateStart: return "ProgramDesignView_Activate_Start"
            case .activateSuccess: return "ProgramDesignView_Activate_Success"
            case .activateFail: return "ProgramDesignView_Activate_Fail"
            case .deleteStart: return "ProgramDesignView_Delete_Start"
            case .deleteSuccess: return "ProgramDesignView_Delete_Success"
            case .deleteFail: return "ProgramDesignView_Delete_Fail"
            case .saveStart: return "ProgramDesignView_Save_Start"
            case .saveSuccess: return "ProgramDesignView_Save_Success"
            case .saveFail: return "ProgramDesignView_Save_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .saveTemplatesFail(let error), .activateFail(let error), .deleteFail(let error), .saveFail(let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .saveTemplatesFail, .activateFail, .deleteFail, .saveFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
