//
//  ABTestManager.swift
//  Compound
//
//  Created by Andrew Coyle on 20/10/2025.
//

import Foundation

@Observable
@MainActor
class ABTestManager {
    
    private let service: ABTestService
    private let logger: LogManager?

    /// Set once a dev-tools override has been applied, so the fetch `init` started cannot land
    /// afterwards and quietly reset it. The override is the more recent intent of the two.
    private var hasOverridden = false

    var activeTests: ActiveABTests
    
    init(service: ABTestService, logger: LogManager? = nil) {
        self.service = service
        self.activeTests = service.activeTests
        self.logger = logger
        self.configure()
    }
    
    private func configure() {
        Task {
            do {
                let fetched = try await service.fetchUpdatedConfig()
                logger?.trackEvent(event: Event.fetchRemoteConfigSuccess)

                // An override applied while this was in flight wins: it is both newer and the
                // only one of the two the user asked for.
                guard !hasOverridden else { return }

                activeTests = fetched
                logger?.addUserProperties(dict: activeTests.eventParameters, isHighPriority: false)
            } catch {
                logger?.trackEvent(event: Event.fetchRemoteConfigFail(error: error))
            }
        }
        activeTests = service.activeTests
        logger?.addUserProperties(dict: activeTests.eventParameters, isHighPriority: false)
    }
    
    func override(updatedTests: ActiveABTests) throws {
        try service.saveUpdatedConfig(updatedTests: updatedTests)
        hasOverridden = true

        // Deliberately not `configure()`. That fires a fresh remote fetch whose result is assigned
        // to `activeTests` when it lands, silently rolling the override back — Remote Config never
        // accepts a client save, so the fetch returns the server's values, not the override. Two
        // overrides in quick succession would also leave two racing tasks deciding the final value
        // by completion order.
        activeTests = service.activeTests
        logger?.addUserProperties(dict: activeTests.eventParameters, isHighPriority: false)
    }
    
    enum Event: LoggableEvent {
        case fetchRemoteConfigSuccess
        case fetchRemoteConfigFail(error: Error)

        var eventName: String {
            switch self {
            case .fetchRemoteConfigSuccess: return "ABMan_FetchRemote_Success"
            case .fetchRemoteConfigFail:    return "ABMan_FetchRemote_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .fetchRemoteConfigFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .fetchRemoteConfigFail:
                return .severe
            default:
                return .analytic
                
            }
        }
    }
}

extension CoreInteractor {
    // MARK: ABTestManager
    
    var activeTests: ActiveABTests {
        abTestManager.activeTests
    }
    
    var paywallTest: PaywallTestOption {
        activeTests.paywallTest
    }

    func override(updatedTests: ActiveABTests) throws {
        try abTestManager.override(updatedTests: updatedTests)
    }

}
