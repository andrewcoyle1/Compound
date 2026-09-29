import SwiftUI

@Observable
@MainActor
class IntegrationsPresenter {
    
    private let interactor: IntegrationsInteractor
    private let router: IntegrationsRouter
    
    init(interactor: IntegrationsInteractor, router: IntegrationsRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    var stravaIsConnected: Bool { interactor.stravaIsConnected }
    var isConnectingStrava: Bool = false
    var isTestingStravaUpload: Bool = false

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onStravaConnectPressed() {
        isConnectingStrava = true
        Task {
            defer { isConnectingStrava = false }
            do {
                try await interactor.stravaAuthenticate()
            } catch {
                router.showSimpleAlert(title: String(localized: "Connection Failed"), subtitle: error.localizedDescription)
            }
        }
    }

    func onStravaDisconnectPressed() {
        interactor.stravaDisconnect()
    }

    func onStravaTestUploadPressed() {
        isTestingStravaUpload = true
        Task {
            defer { isTestingStravaUpload = false }
            do {
                try await interactor.stravaTestUpload()
                router.showSimpleAlert(title: String(localized: "Upload Successful"), subtitle: String(localized: "Check your Strava account for \"DialedIn Test Upload\"."))
            } catch {
                router.showSimpleAlert(title: String(localized: "Upload Failed"), subtitle: error.localizedDescription)
            }
        }
    }
}

extension IntegrationsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "IntegrationsView_Appear"
            case .onDisappear: return "IntegrationsView_Disappear"
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
