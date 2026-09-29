import SwiftUI

@Observable
@MainActor
class ProgramDesignPresenter {
    
    private let interactor: ProgramDesignInteractor
    private let router: ProgramDesignRouter
    
    var userId: String {
        interactor.userId ?? ""
    }
    
    var favouriteGymProfile: GymProfileModel? {
        interactor.favouriteGymProfile
    }
    
    var program: TrainingProgram
    private(set) var isSaving: Bool = false

    /// A program of rest days alone has nothing to activate, and a second tap mid-save wrote twice.
    var canSave: Bool {
        !isSaving && dayPlans.contains { !$0.exercises.isEmpty }
    }
    
    /// The program's days, read and written straight through to `program.workoutTemplates`.
    ///
    /// This used to be a second array holding its own copy of the days. The program settings
    /// sheet edits the program through a `Binding`, so reordering the days there changed
    /// `program.workoutTemplates` while this copy kept the old order — the day tabs carried on
    /// showing the old order, and the next edit on this screen wrote the stale copy back over
    /// the reorder. One array cannot drift from itself.
    var dayPlans: [WorkoutTemplateModel] {
        get { program.workoutTemplates }
        set { program.workoutTemplates = newValue }
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

    var isProgramActive: Bool {
        interactor.activeTrainingProgram?.id == program.id
    }
    
    init(interactor: ProgramDesignInteractor, router: ProgramDesignRouter, program: TrainingProgram) {
        self.interactor = interactor
        self.router = router

        var program = program
        if let firstPlan = program.workoutTemplates.first {
            self.selectedWorkoutTemplateModel = firstPlan
        } else {
            let restDay = WorkoutTemplateModel(
                id: UUID().uuidString,
                authorId: interactor.userId ?? "",
                name: "Rest",
                exercises: []
            )
            self.selectedWorkoutTemplateModel = restDay
            program.workoutTemplates = [restDay]
        }
        self.program = program
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
            name: "Rest Day",
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
        
    func onProgramSettingsPressed(program: Binding<TrainingProgram>) {
        router.showProgramSettingsView(program: program)
    }
    
    func onActivatePressed(delegate: ProgramDesignDelegate) {
        guard canSave else { return }
        router.showAlert(title: String(localized: "Save Workout Templates"), subtitle: String(localized: "Would you like to save the workout templates in the training program for use independently?")) {
            AnyView(
                VStack {
                    Button {
                        Task { await self.saveTemplatesAndActivate(delegate: delegate) }
                    } label: {
                        Text("Yes")
                    }
                    Button {
                        Task { await self.activateProgram(delegate: delegate) }
                    } label: {
                        Text("No")
                    }
                    Button(role: .close) { }
                }
            )
        }
    }

    /// Saves each workout day as a standalone template, then activates. A failure here
    /// used to be swallowed by an unstructured `Task`, leaving the program un-activated with
    /// no feedback; now it surfaces and activation is skipped.
    ///
    /// Rest days are skipped: an empty template in the library is nothing anyone would start.
    /// ponytail: sequential saves; a failure part-way leaves the earlier templates saved.
    func saveTemplatesAndActivate(delegate: ProgramDesignDelegate) async {
        isSaving = true
        defer { isSaving = false }
        do {
            for workoutTemplate in dayPlans where !workoutTemplate.exercises.isEmpty {
                try await interactor.saveWorkoutTemplate(workoutTemplate: workoutTemplate, image: nil)
            }
        } catch {
            router.showAlert(error: error)
            return
        }

        await activateProgram(delegate: delegate)
    }

    /// This was declared `async throws` while wrapping its whole body in a nested `Task`, so
    /// it returned immediately and could never throw — the callers' `try await` was a no-op
    /// and the nested task's errors went nowhere. It is now a plain `async` call that handles
    /// its own errors, which is what the alert path already assumed.
    func activateProgram(delegate: ProgramDesignDelegate) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await interactor.saveTrainingProgram(trainingProgram: program)
            try await interactor.setActiveTrainingProgram(programId: program.id)
            // Onboarding hands in the closure that resumes it. This screen used to route
            // onboarding itself and never call it, so the closure was carried four screens for nothing.
            if let onComplete = delegate.onComplete {
                onComplete()
            } else {
                router.dismissEnvironment()
            }
        } catch {
            router.showAlert(error: error)
        }
    }

    /// Confirming used to pop one screen, back to the icon picker, with the program intact.
    /// Under onboarding this screen is pushed, so one screen back is all there is to discard;
    /// as a cover or the edit sheet the whole environment goes.
    func onDismissPressed(delegate: ProgramDesignDelegate) {
        router.showAlert(
            title: String(localized: "Discard Program"),
            subtitle: String(localized: "Are you sure you want to discard your changes?"),
            buttons: {
                AnyView(
                    HStack {
                        Button(role: .cancel) { }
                        Button("Discard", role: .destructive) {
                            if delegate.onComplete == nil {
                                self.router.dismissEnvironment()
                            } else {
                                self.router.dismissScreen()
                            }
                        }
                    }
                )
            }
        )
    }

    func onSavePressed(delegate: ProgramDesignDelegate) {
        guard canSave else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await interactor.saveTrainingProgram(trainingProgram: program)
                router.dismissEnvironment()
            } catch {
                router.showAlert(error: error)
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
                desiredName = "Rest Day"
            } else {
                desiredName = "Workout \(letterForWorkoutIndex(workoutIndex))"
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
        if trimmed == "Rest" || trimmed == "Rest Day" {
            return true
        }
        if trimmed.hasPrefix("Workout "), let suffix = trimmed.split(separator: " ").last {
            return suffix.count == 1 && suffix.first?.isLetter == true
        }
        return false
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

extension ProgramDesignPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "ProgramDesignView_Appear"
            case .onDisappear: return "ProgramDesignView_Disappear"
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
