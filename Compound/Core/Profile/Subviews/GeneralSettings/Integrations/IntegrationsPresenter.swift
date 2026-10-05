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
        interactor.trackEvent(event: Event.stravaConnectStart)
        Task {
            defer { isConnectingStrava = false }
            do {
                try await interactor.stravaAuthenticate()
                interactor.trackEvent(event: Event.stravaConnectSuccess)
                stravaIsConnected = interactor.stravaIsConnected
            } catch where SignInCancellation.isCancellation(error) {
                // Closing Strava's sign-in page is a choice, not a failed connection.
                interactor.trackEvent(event: Event.stravaConnectCancelled)
            } catch StravaError.missingUploadPermission {
                interactor.trackEvent(event: Event.stravaConnectFail(error: StravaError.missingUploadPermission))
                router.showSimpleAlert(
                    title: String(localized: "Unable to Connect Strava"),
                    subtitle: StravaError.missingUploadPermission.localizedDescription
                )
            } catch {
                interactor.trackEvent(event: Event.stravaConnectFail(error: error))
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
        interactor.trackEvent(event: Event.stravaDisconnect)
        interactor.stravaDisconnect()
        stravaIsConnected = interactor.stravaIsConnected
    }

    func onStravaTestUploadPressed() {
        isTestingStravaUpload = true
        interactor.trackEvent(event: Event.stravaTestUploadStart)
        Task {
            defer { isTestingStravaUpload = false }
            do {
                try await interactor.stravaTestUpload()
                interactor.trackEvent(event: Event.stravaTestUploadSuccess)
                interactor.showAppToast(AppToast(style: .success, message: String(localized: "Test upload sent to Strava")))
            } catch {
                interactor.trackEvent(event: Event.stravaTestUploadFail(error: error))
                // A refused token disconnects, so the row has to say so.
                stravaIsConnected = interactor.stravaIsConnected
                router.showSimpleAlert(title: String(localized: "Upload Failed"), subtitle: error.localizedDescription)
            }
        }
    }
}

extension IntegrationsPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case stravaConnectStart
        case stravaConnectSuccess
        case stravaConnectCancelled
        case stravaConnectFail(error: Error)
        case stravaDisconnect
        case stravaTestUploadStart
        case stravaTestUploadSuccess
        case stravaTestUploadFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear: return "IntegrationsView_Appear"
            case .onDisappear: return "IntegrationsView_Disappear"
            case .stravaConnectStart: return "IntegrationsView_StravaConnect_Start"
            case .stravaConnectSuccess: return "IntegrationsView_StravaConnect_Success"
            case .stravaConnectCancelled: return "IntegrationsView_StravaConnect_Cancelled"
            case .stravaConnectFail: return "IntegrationsView_StravaConnect_Fail"
            case .stravaDisconnect: return "IntegrationsView_StravaDisconnect"
            case .stravaTestUploadStart: return "IntegrationsView_StravaTestUpload_Start"
            case .stravaTestUploadSuccess: return "IntegrationsView_StravaTestUpload_Success"
            case .stravaTestUploadFail: return "IntegrationsView_StravaTestUpload_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .stravaConnectFail(let error), .stravaTestUploadFail(let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .stravaConnectFail, .stravaTestUploadFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
