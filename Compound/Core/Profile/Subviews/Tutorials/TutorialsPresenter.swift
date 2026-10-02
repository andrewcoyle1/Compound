import SwiftUI

@Observable
@MainActor
class TutorialsPresenter {
    
    private let interactor: TutorialsInteractor
    private let router: TutorialsRouter
    
    init(interactor: TutorialsInteractor, router: TutorialsRouter) {
        self.interactor = interactor
        self.router = router
    }

    // `onResetTutorialsPressed` was here, empty, behind a "Reset Tutorials" call to action. Nothing
    // in the app records tutorial progress, so there was nothing for it to reset. The button is gone
    // with it; when first-run guidance exists, both come back together.

    func onViewAppear(delegate: TutorialsDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: TutorialsDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
}

extension TutorialsPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: TutorialsDelegate)
        case onDisappear(delegate: TutorialsDelegate)

        var eventName: String {
            switch self {
            case .onAppear:                 return "TutorialsView_Appear"
            case .onDisappear:              return "TutorialsView_Disappear"
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
