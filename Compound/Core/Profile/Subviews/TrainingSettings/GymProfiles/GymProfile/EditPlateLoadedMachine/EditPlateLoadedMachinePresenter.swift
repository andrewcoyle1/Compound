import SwiftUI

@Observable
@MainActor
class EditPlateLoadedMachinePresenter {
    
    private let interactor: EditPlateLoadedMachineInteractor
    private let router: EditPlateLoadedMachineRouter
    
    private let plateLoadedMachineBinding: Binding<PlateLoadedMachine>
    var selectedUnit: ExerciseWeightUnit
    
    init(interactor: EditPlateLoadedMachineInteractor, router: EditPlateLoadedMachineRouter, plateLoadedMachineBinding: Binding<PlateLoadedMachine>) {
        self.interactor = interactor
        self.router = router
        self.plateLoadedMachineBinding = plateLoadedMachineBinding
        self.selectedUnit = plateLoadedMachineBinding.wrappedValue.unit
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    var plateLoadedMachine: PlateLoadedMachine {
        get { plateLoadedMachineBinding.wrappedValue }
        set { plateLoadedMachineBinding.wrappedValue = newValue }
    }
    
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
