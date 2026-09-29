//
//  NetworkMonitor.swift
//  DialedIn
//
//  Whether the device has a network, for the actions that need the server to answer before they
//  can finish: Cloud Function calls, image uploads, claiming a username, sharing and invites.
//  Plain sync-engine writes do not ask — Firestore queues them and the listener shows them at once.
//

import Foundation
import Network
import os

final class NetworkMonitor: Sendable {

    static let shared = NetworkMonitor()

    /// `OFFLINE_TESTING` pretends there is no network. The Development scheme also points Firebase
    /// at an unreachable host under it (`BuildConfiguration.configure`), since the simulator's own
    /// network cannot be turned off.
    static let isOfflineTesting = ProcessInfo.processInfo.arguments.contains("OFFLINE_TESTING")

    private let monitor = NWPathMonitor()
    /// Online until the first path arrives: an unknown status should not block anything.
    private let satisfied = OSAllocatedUnfairLock(initialState: true)

    private init() {
        monitor.pathUpdateHandler = { [satisfied] path in
            satisfied.withLock { $0 = path.status == .satisfied }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }

    var isOffline: Bool {
        Self.isOfflineTesting || !satisfied.withLock { $0 }
    }

    /// Throws `OfflineError` when there is no network, for a service about to make a request that
    /// would otherwise wait for one (a Storage upload retries for ten minutes).
    static func requireOnline() throws {
        if shared.isOffline { throw OfflineError() }
    }
}

/// An action that needs the server was tried without a network.
struct OfflineError: LocalizedError {
    static let title = "You're offline"
    static let message = "This needs an internet connection. Try again when you're back online."

    var errorDescription: String? { "\(Self.title). \(Self.message)" }
}

extension Error {

    /// True for errors that mean the server could not be reached, as opposed to it saying no.
    var isOfflineError: Bool {
        if self is OfflineError { return true }
        let error = self as NSError
        switch error.domain {
        case NSURLErrorDomain:
            return [
                NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
                NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorTimedOut
            ].contains(error.code)
        case "FIRFirestoreErrorDomain", "com.firebase.functions":
            // 14 is `unavailable` in both: the backend could not be reached.
            if error.code == 14 { return true }
        default:
            break
        }
        return (error.userInfo[NSUnderlyingErrorKey] as? Error)?.isOfflineError ?? false
    }
}

extension GlobalInteractor {

    /// For an action that needs the server: false, after showing "You're offline", when there is
    /// no network. `guard interactor.ensureOnline(or: router) else { return }`, before any spinner.
    func ensureOnline(or router: GlobalRouter) -> Bool {
        guard isOffline else { return true }
        trackEvent(eventName: "Offline_ActionBlocked", parameters: nil, type: .analytic)
        router.showOfflineAlert()
        return false
    }
}

extension GlobalRouter {

    func showOfflineAlert() {
        showSimpleAlert(title: OfflineError.title, subtitle: OfflineError.message)
    }
}
