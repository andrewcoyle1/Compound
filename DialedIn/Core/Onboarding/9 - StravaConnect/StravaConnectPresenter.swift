//
//  StravaConnectPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 09/03/2026.
//

import SwiftUI

@Observable
@MainActor
class StravaConnectPresenter {
    private let interactor: StravaConnectInteractor
    private let router: StravaConnectRouter

    private(set) var isConnecting: Bool = false

    var isConnected: Bool { interactor.stravaIsConnected }

    init(interactor: StravaConnectInteractor, router: StravaConnectRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onConnectPressed() {
        isConnecting = true
        Task {
            defer { isConnecting = false }
            do {
                try await interactor.stravaAuthenticate()
                interactor.trackEvent(event: Event.connectSuccess)
            } catch {
                interactor.trackEvent(event: Event.connectFail(error: error))
                router.showSimpleAlert(title: String(localized: "Connection Failed"), subtitle: error.localizedDescription)
            }
        }
    }

    func onContinuePressed() {
        interactor.trackEvent(event: Event.continue)
        router.showOnboardingCompletedView()
    }

    func onSkipPressed() {
        interactor.trackEvent(event: Event.skip)
        router.showOnboardingCompletedView()
    }

    enum Event: LoggableEvent {
        case onAppear
        case connectSuccess
        case connectFail(error: Error)
        case `continue`
        case skip

        var eventName: String {
            switch self {
            case .onAppear:       return "StravaConnect_Appear"
            case .connectSuccess: return "StravaConnect_Connect_Success"
            case .connectFail:    return "StravaConnect_Connect_Fail"
            case .continue:       return "StravaConnect_Continue"
            case .skip:           return "StravaConnect_Skip"
            }
        }

        var parameters: [String: Any]? {
            if case .connectFail(error: let error) = self { return error.eventParameters }
            return nil
        }

        var type: LogType {
            if case .connectFail = self { return .severe }
            return .analytic
        }
    }
}
