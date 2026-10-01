import SwiftUI

@Observable
@MainActor
class EditLoadableAccessoryPresenter {
    
    private let interactor: EditLoadableAccessoryInteractor
    private let router: EditLoadableAccessoryRouter
    
    private let loadableAccessoryBinding: Binding<LoadableAccessoryEquipment>
    var selectedUnit: ExerciseWeightUnit
    
    var loadableAccessory: LoadableAccessoryEquipment {
        get { loadableAccessoryBinding.wrappedValue }
        set { loadableAccessoryBinding.wrappedValue = newValue }
    }
    
    init(interactor: EditLoadableAccessoryInteractor, router: EditLoadableAccessoryRouter, loadableAccessoryBinding: Binding<LoadableAccessoryEquipment>) {
        self.interactor = interactor
        self.router = router
        self.loadableAccessoryBinding = loadableAccessoryBinding
        self.selectedUnit = loadableAccessoryBinding.wrappedValue.unit
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
    
}

extension EditLoadableAccessoryPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "EditLoadableAccessoryView_Appear"
            case .onDisappear: return "EditLoadableAccessoryView_Disappear"
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
