import SwiftUI

@Observable
@MainActor
class AddFixedWeightBarPresenter {
    
    private let interactor: AddFixedWeightBarInteractor
    private let router: AddFixedWeightBarRouter
    
    var fixedWeightBar: Binding<FixedWeightBars>
    
    var fixedWeightBarBaseWeight: FixedWeightBarsBaseWeight
    let unit: ExerciseWeightUnit
    
    init(interactor: AddFixedWeightBarInteractor, router: AddFixedWeightBarRouter, delegate: AddFixedWeightBarDelegate) {
        self.interactor = interactor
        self.router = router
        self.fixedWeightBar = delegate.fixedWeightBar
        self.fixedWeightBarBaseWeight = FixedWeightBarsBaseWeight(
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
    
    func onSavePressed() {
        guard fixedWeightBar.wrappedValue.baseWeights.contains(where: {
            $0.baseWeight == fixedWeightBarBaseWeight.baseWeight && $0.unit == fixedWeightBarBaseWeight.unit
        }) == false else {
            router.showSimpleAlert(title: String(localized: "Unable to add"), subtitle: String(localized: "This weight is already added."))
            return 
        }
        self.fixedWeightBar.wrappedValue.baseWeights.append(self.fixedWeightBarBaseWeight)
        router.dismissScreen()
    }
}

extension AddFixedWeightBarPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "AddFixedWeightBarView_Appear"
            case .onDisappear: return "AddFixedWeightBarView_Disappear"
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
