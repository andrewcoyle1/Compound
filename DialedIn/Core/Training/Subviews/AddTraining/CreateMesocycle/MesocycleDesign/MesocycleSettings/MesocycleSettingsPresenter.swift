import SwiftUI

@Observable
@MainActor
class MesocycleSettingsPresenter {
    
    private let interactor: MesocycleSettingsInteractor
    private let router: MesocycleSettingsRouter

    /// A second tap on Activate while the first was saving ran the write twice.
    private(set) var isSaving = false

    init(interactor: MesocycleSettingsInteractor, router: MesocycleSettingsRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onEditNamePressed(mesocycle: Binding<Mesocycle>) {
        router.showRenameMesocycleView(delegate: RenameWorkoutTemplateModelDelegate(
            initialName: mesocycle.wrappedValue.name,
            onSave: { mesocycle.wrappedValue.name = $0 }
        ))
    }

    func onEditColourIconPressed(mesocycle: Binding<Mesocycle>) {
        router.showEditMesocycleColourIconView(
            colour: mesocycle.wrappedValue.colour,
            icon: mesocycle.wrappedValue.icon,
            onSave: { colour, icon in
                mesocycle.wrappedValue.colour = colour
                mesocycle.wrappedValue.icon = icon
            }
        )
    }

    func onEditDayOrderPressed(mesocycle: Binding<Mesocycle>) {
        router.showEditDayOrderView(
            dayPlans: mesocycle.wrappedValue.workoutTemplates,
            onSave: { mesocycle.wrappedValue.workoutTemplates = $0 }
        )
    }

    /// The days in order, by name. It used to read "R W W ".
    func dayOrderSubtitle(mesocycle: Mesocycle) -> String {
        mesocycle.workoutTemplates.map(\.name).joined(separator: ", ")
    }

    func onEditDeloadPressed(mesocycle: Binding<Mesocycle>) {
        router.showEditDeloadView(
            selected: mesocycle.wrappedValue.deload,
            onSave: { mesocycle.wrappedValue.deload = $0 }
        )
    }

    func onActivatePressed(mesocycle: Mesocycle) {
        guard !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await interactor.saveMesocycle(mesocycle: mesocycle)
                try await interactor.setActiveMesocycle(mesocycleId: mesocycle.id)
                interactor.playHaptic(option: .success)
                router.dismissScreen()
            } catch {
                interactor.playHaptic(option: .error)
                router.showAlert(title: String(localized: "Unable to Activate Program"), error: error)
            }
        }
    }
    
}

extension MesocycleSettingsPresenter {
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
