import SwiftUI

@Observable
@MainActor
class EditLoadableAccessoryPresenter {
    
    private let interactor: EditLoadableAccessoryInteractor
    private let router: EditLoadableAccessoryRouter
    
    private let loadableAccessoryBinding: Binding<LoadableAccessoryEquipment>

    /// Edited in place: the unit picker used to set a copy that was never written back.
    var loadableAccessory: LoadableAccessoryEquipment {
        get { loadableAccessoryBinding.wrappedValue }
        set { loadableAccessoryBinding.wrappedValue = newValue }
    }

    /// What the accessory weighs empty; never below nothing.
    var baseWeight: Double {
        get { loadableAccessory.baseWeight }
        set { loadableAccessory.baseWeight = max(newValue, 0) }
    }
    
    init(interactor: EditLoadableAccessoryInteractor, router: EditLoadableAccessoryRouter, loadableAccessoryBinding: Binding<LoadableAccessoryEquipment>) {
        self.interactor = interactor
        self.router = router
        self.loadableAccessoryBinding = loadableAccessoryBinding
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
