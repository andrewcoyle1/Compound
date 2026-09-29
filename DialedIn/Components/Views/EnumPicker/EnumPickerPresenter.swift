import SwiftUI

@Observable
@MainActor
class EnumPickerPresenter {
    
    private let interactor: EnumPickerInteractor
    private let router: EnumPickerRouter
    
    init(interactor: EnumPickerInteractor, router: EnumPickerRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onSelect<Item: PickableItem>(item: Item, binding: Binding<Item?>) {
        binding.wrappedValue = item
        interactor.playHaptic(option: .selection)
        router.dismissScreen()
    }
    
    func onDismissPressed() {
        router.dismissScreen()
    }
    
    func onDeletePressed<Item: PickableItem>(binding: Binding<Item?>) {
        binding.wrappedValue = nil
        router.dismissScreen()
    }

}

extension EnumPickerPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear:     return "EnumPickerView_Appear"
            case .onDisappear:  return "EnumPickerView_Disappear"
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
