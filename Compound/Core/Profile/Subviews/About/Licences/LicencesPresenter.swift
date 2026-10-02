import SwiftUI

@Observable
@MainActor
class LicencesPresenter {
    
    private let interactor: LicencesInteractor
    private let router: LicencesRouter
    
    init(interactor: LicencesInteractor, router: LicencesRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    let groups = Licence.groupedByLicence

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
}

extension LicencesPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear:             return "LicencesView_Appear"
            case .onDisappear:          return "LicencesView_Disappear"
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
