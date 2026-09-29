import SwiftUI

@Observable
@MainActor
class AddBodyWeightPresenter {
    
    private let interactor: AddBodyWeightInteractor
    private let router: AddBodyWeightRouter
    
    var bodyWeight: Binding<BodyWeights>
    
    var bodyWeightAvailable: BodyWeightsAvailable
    let unit: ExerciseWeightUnit
        
    init(interactor: AddBodyWeightInteractor, router: AddBodyWeightRouter, delegate: AddBodyWeightDelegate) {
        self.interactor = interactor
        self.router = router
        self.bodyWeight = delegate.bodyWeight
        self.bodyWeightAvailable = BodyWeightsAvailable(
            id: UUID().uuidString,
            availableWeights: 0,
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
        guard bodyWeight.wrappedValue.range.contains(where: {
            $0.availableWeights == bodyWeightAvailable.availableWeights && $0.unit == bodyWeightAvailable.unit
        }) == false else {
            router.showSimpleAlert(title: String(localized: "Unable to add"), subtitle: String(localized: "This weight is already added."))
            return 
        }
        self.bodyWeight.wrappedValue.range.append(self.bodyWeightAvailable)
        router.dismissScreen()
    }
    
}

extension AddBodyWeightPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "AddBodyWeightView_Appear"
            case .onDisappear: return "AddBodyWeightView_Disappear"
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
