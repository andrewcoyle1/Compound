import SwiftUI

@Observable
@MainActor
class ProgramSettingsPresenter {
    
    private let interactor: ProgramSettingsInteractor
    private let router: ProgramSettingsRouter
    
    init(interactor: ProgramSettingsInteractor, router: ProgramSettingsRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    func onEditNamePressed(program: Binding<TrainingProgram>) {
        router.showRenameProgramView(delegate: RenameWorkoutTemplateModelDelegate(
            initialName: program.wrappedValue.name,
            onSave: { program.wrappedValue.name = $0 }
        ))
    }

    func onEditColourIconPressed(program: Binding<TrainingProgram>) {
        router.showEditProgramColourIconView(
            colour: program.wrappedValue.colour,
            icon: program.wrappedValue.icon,
            onSave: { colour, icon in
                program.wrappedValue.colour = colour
                program.wrappedValue.icon = icon
            }
        )
    }

    func onEditDayOrderPressed(program: Binding<TrainingProgram>) {
        router.showEditDayOrderView(
            dayPlans: program.wrappedValue.workoutTemplates,
            onSave: { program.wrappedValue.workoutTemplates = $0 }
        )
    }

    func onEditDeloadPressed(program: Binding<TrainingProgram>) {
        router.showEditDeloadView(
            selected: program.wrappedValue.deload,
            onSave: { program.wrappedValue.deload = $0 }
        )
    }

    func onActivatePressed(program: TrainingProgram) {
        Task {
            do {
                try await interactor.saveTrainingProgram(trainingProgram: program)
                try await interactor.setActiveTrainingProgram(programId: program.id)
                interactor.playHaptic(option: .success)
                router.dismissScreen()
            } catch {
                interactor.playHaptic(option: .error)
                router.showAlert(error: error)
            }
        }
    }
    
}

extension ProgramSettingsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "ProgramSettingsView_Appear"
            case .onDisappear: return "ProgramSettingsView_Disappear"
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
