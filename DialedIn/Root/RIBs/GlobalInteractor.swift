//
//  GlobalInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 29/01/2026.
//

@MainActor
protocol GlobalInteractor {
    func trackEvent(eventName: String, parameters: [String: Any]?, type: LogType)
    func trackEvent(event: AnyLoggableEvent)
    func trackEvent(event: LoggableEvent)
    func trackScreenEvent(event: LoggableEvent)
    
    func playHaptic(option: HapticOption)

    /// Shows an app-level toast. Lives here beside `playHaptic` for the same reason: it is feedback
    /// every screen may need, and it has to be reachable from work that outlives the screen that
    /// started it.
    func showAppToast(_ toast: AppToast)

    /// No network, so an action that needs the server should not start. A requirement, with the
    /// live answer as its default, so a test double can say it is offline.
    var isOffline: Bool { get }
}

extension GlobalInteractor {
    var isOffline: Bool { NetworkMonitor.shared.isOffline }
}
