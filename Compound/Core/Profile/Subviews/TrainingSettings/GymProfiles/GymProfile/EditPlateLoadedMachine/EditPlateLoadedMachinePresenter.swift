import SwiftUI

@Observable
@MainActor
class EditPlateLoadedMachinePresenter {
    
    private let interactor: EditPlateLoadedMachineInteractor
    private let router: EditPlateLoadedMachineRouter
    
    private let plateLoadedMachineBinding: Binding<PlateLoadedMachine>
    private let originalName: String
    
    init(interactor: EditPlateLoadedMachineInteractor, router: EditPlateLoadedMachineRouter, plateLoadedMachineBinding: Binding<PlateLoadedMachine>) {
        self.interactor = interactor
        self.router = router
        self.plateLoadedMachineBinding = plateLoadedMachineBinding
        self.originalName = plateLoadedMachineBinding.wrappedValue.name
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
        // A machine left without a name keeps the one it had.
        if plateLoadedMachine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            plateLoadedMachine.name = originalName
        }
    }

    var plateLoadedMachine: PlateLoadedMachine {
        get { plateLoadedMachineBinding.wrappedValue }
        set { plateLoadedMachineBinding.wrappedValue = newValue }
    }

    /// Only a duplicate or the user's own machine can be renamed.
    var isCustom: Bool { plateLoadedMachine.isCustom }
    
    func onDismissPressed() {
        router.dismissScreen()
    }
}

extension EditPlateLoadedMachinePresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "EditPlateLoadedMachineView_Appear"
            case .onDisappear: return "EditPlateLoadedMachineView_Disappear"
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
