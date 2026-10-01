import SwiftUI

@Observable
@MainActor
class InactiveMesocyclePresenter {
    
    private let interactor: InactiveMesocycleInteractor
    private let router: InactiveMesocycleRouter
    
    init(interactor: InactiveMesocycleInteractor, router: InactiveMesocycleRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: InactiveMesocycleDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: InactiveMesocycleDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
}

extension InactiveMesocyclePresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: InactiveMesocycleDelegate)
        case onDisappear(delegate: InactiveMesocycleDelegate)

        var eventName: String {
            switch self {
            case .onAppear:                 return "InactiveTrainingProgramView_Appear"
            case .onDisappear:              return "InactiveTrainingProgramView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
//            default:
//                return nil
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
