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

    var isConnectingStrava: Bool = false
    var isDisconnectingStrava: Bool = false
    var isTestingStravaUpload: Bool = false

    var stravaIsConnected: Bool { interactor.stravaAthlete != nil }

    var stravaSubtitle: String {
        guard let athlete = interactor.stravaAthlete else { return String(localized: "Not connected") }
        return athlete.name.isEmpty ? String(localized: "Connected") : String(localized: "Connected as \(athlete.name)")
    }

    /// Workouts queued and not on Strava yet, or `nil` when none are.
    var pendingUploadsText: String? {
        let count = interactor.stravaPendingUploadCount
        return count == 0 ? nil : String(localized: "\(count) workouts waiting to upload")
    }

    var backfillCount: Int { interactor.stravaBackfillCount }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
        // The connection can change elsewhere: another phone, or revoking Compound on strava.com.
        Task { await interactor.stravaRefreshConnection() }
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
                offerBackfill()
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

    /// Right after connecting, the workouts already logged are the obvious next question.
    private func offerBackfill() {
        let count = backfillCount
        guard count > 0 else { return }
        router.showConfirmationDialog(
            title: String(localized: "Upload \(count) past workouts to Strava?"),
            subtitle: String(localized: "Each one goes up with its sets. A long history can take a while."),
            buttons: {
                AnyView(VStack {
                    Button("Upload Past Workouts") { self.onStravaBackfillPressed() }
                    Button("Not Now", role: .cancel) { }
                })
            }
        )
    }

    func onStravaBackfillPressed() {
        let queued = interactor.stravaQueueBackfill()
        interactor.trackEvent(event: Event.stravaBackfill(count: queued))
        guard queued > 0 else { return }
        interactor.showAppToast(AppToast(style: .success, message: String(localized: "\(queued) workouts queued for Strava")))
        Task { await interactor.stravaSyncPendingUploads() }
    }

    /// Disconnecting asks first: it was one stray tap on a row away.
    func onStravaDisconnectPressed() {
        router.showConfirmationDialog(
            title: String(localized: "Disconnect Strava?"),
            subtitle: String(localized: "Workouts will stop uploading to Strava, and activities imported from it are removed."),
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
        isDisconnectingStrava = true
        Task {
            defer { isDisconnectingStrava = false }
            do {
                try await interactor.stravaDisconnect()
            } catch {
                interactor.trackEvent(event: Event.stravaDisconnectFail(error: error))
                router.showSimpleAlert(
                    title: String(localized: "Unable to Disconnect Strava"),
                    subtitle: String(localized: "Check your internet connection and try again.")
                )
            }
        }
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
        case stravaDisconnectFail(error: Error)
        case stravaBackfill(count: Int)
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
            case .stravaDisconnectFail: return "IntegrationsView_StravaDisconnect_Fail"
            case .stravaBackfill: return "IntegrationsView_StravaBackfill"
            case .stravaTestUploadStart: return "IntegrationsView_StravaTestUpload_Start"
            case .stravaTestUploadSuccess: return "IntegrationsView_StravaTestUpload_Success"
            case .stravaTestUploadFail: return "IntegrationsView_StravaTestUpload_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .stravaConnectFail(let error), .stravaTestUploadFail(let error), .stravaDisconnectFail(let error):
                return error.eventParameters
            case .stravaBackfill(let count):
                return ["count": count]
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .stravaConnectFail, .stravaTestUploadFail, .stravaDisconnectFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
