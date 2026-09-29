import SwiftUI

@Observable
@MainActor
class IntegrationsPresenter {
    
    private let interactor: IntegrationsInteractor
    private let router: IntegrationsRouter
    
    init(interactor: IntegrationsInteractor, router: IntegrationsRouter) {
        self.interactor = interactor
        self.router = router
        self.stravaIsConnected = interactor.stravaIsConnected
    }

    /// Stored and refreshed after each change: the manager reads it from the Keychain, which
    /// Observation cannot see, so the row kept saying "Connected" after Disconnect.
    private(set) var stravaIsConnected: Bool
    var isConnectingStrava: Bool = false
    var isTestingStravaUpload: Bool = false

    func onViewAppear() {
        stravaIsConnected = interactor.stravaIsConnected
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
                stravaIsConnected = interactor.stravaIsConnected
            } catch where SignInCancellation.isCancellation(error) {
                // Closing Strava's sign-in page is a choice, not a failed connection.
            } catch {
                // The raw error is written for developers ("The operation couldn't be completed").
                router.showSimpleAlert(
                    title: String(localized: "Unable to Connect Strava"),
                    subtitle: String(localized: "Check your internet connection and try again.")
                )
            }
        }
    }

    /// Disconnecting asks first: it was one stray tap on a row away.
    func onStravaDisconnectPressed() {
        router.showConfirmationDialog(
            title: String(localized: "Disconnect Strava?"),
            subtitle: String(localized: "Workouts will stop uploading to Strava."),
            buttons: {
                AnyView(VStack {
                    Button("Disconnect", role: .destructive) { self.onStravaDisconnectConfirmed() }
                    Button("Cancel", role: .cancel) { }
                })
            }
        )
    }

    func onStravaDisconnectConfirmed() {
        interactor.stravaDisconnect()
        stravaIsConnected = interactor.stravaIsConnected
    }

    func onStravaTestUploadPressed() {
        isTestingStravaUpload = true
        Task {
            defer { isTestingStravaUpload = false }
            do {
                try await interactor.stravaTestUpload()
                interactor.showAppToast(AppToast(style: .success, message: String(localized: "Test upload sent to Strava")))
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
