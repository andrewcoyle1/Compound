import SwiftUI

@Observable
@MainActor
class EquipmentPickerPresenter {
    
    private let interactor: EquipmentPickerInteractor
    private let router: EquipmentPickerRouter
    
    init(interactor: EquipmentPickerInteractor, router: EquipmentPickerRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onSelect(item: AnyEquipment, binding: Binding<[EquipmentRef]>) {
        if let index = binding.wrappedValue.firstIndex(of: item.ref) {
            binding.wrappedValue.remove(at: index)
        } else {
            binding.wrappedValue.append(item.ref)
        }
        interactor.playHaptic(option: .selection)
    }
    
    func onDismissPressed() {
        router.dismissScreen()
    }
    
}

extension EquipmentPickerPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "EquipmentPickerView_Appear"
            case .onDisappear: return "EquipmentPickerView_Disappear"
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
