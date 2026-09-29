import SwiftUI

@Observable
@MainActor
class AddLoadableBarPresenter {
    
    private let interactor: AddLoadableBarInteractor
    private let router: AddLoadableBarRouter
    
    var loadableBar: Binding<LoadableBars>
    
    var loadableBarBaseWeight: LoadableBarsBaseWeight
    let unit: ExerciseWeightUnit
    
    init(interactor: AddLoadableBarInteractor, router: AddLoadableBarRouter, delegate: AddLoadableBarDelegate) {
        self.interactor = interactor
        self.router = router
        self.loadableBar = delegate.loadableBar
        self.loadableBarBaseWeight = LoadableBarsBaseWeight(
            id: UUID().uuidString,
            baseWeight: 0,
            unit: delegate.unit,
            isActive: true
        )
        self.unit = delegate.unit
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
    
    /// Why the form cannot be saved yet, shown under the fields; nil when it can. Confirm stays
    /// disabled until then, rather than reporting the problem in an alert after the tap.
    var validationMessage: String? {
        guard loadableBar.wrappedValue.baseWeights.contains(where: {
            $0.baseWeight == loadableBarBaseWeight.baseWeight && $0.unit == loadableBarBaseWeight.unit
        }) == false else {
            return String(localized: "This weight is already added.")
        }
        return nil
    }

    func onSavePressed() {
        guard validationMessage == nil else { return }
        self.loadableBar.wrappedValue.baseWeights.append(self.loadableBarBaseWeight)
        router.dismissScreen()
    }
    
}

extension AddLoadableBarPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "AddLoadableBarView_Appear"
            case .onDisappear: return "AddLoadableBarView_Disappear"
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
