import SwiftUI

@Observable
@MainActor
class CreateMesocyclePresenter {
    
    private let interactor: CreateMesocycleInteractor
    private let router: CreateMesocycleRouter
    
    init(interactor: CreateMesocycleInteractor, router: CreateMesocycleRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onNextPressed(delegate: CreateMesocycleDelegate) {
        router.showNameMesocycleView(delegate: NameMesocycleDelegate(onComplete: delegate.onComplete))
    }
    
}

extension CreateMesocyclePresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "CreateProgramView_Appear"
            case .onDisappear: return "CreateProgramView_Disappear"
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
