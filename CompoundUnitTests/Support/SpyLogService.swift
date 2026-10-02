//
//  SpyLogService.swift
//  CompoundUnitTests
//

import Foundation
@testable import Compound

/// Records the names of the events a manager hands its `LogManager`. `LogService` is `Sendable`,
/// so the store has to be one too.
final class SpyLogService: LogService, @unchecked Sendable {
    private let lock = NSLock()
    private var names: [String] = []

    var trackedEventNames: [String] {
        lock.withLock { names }
    }

    func identifyUser(userId: String, name: String?, email: String?) { }
    func addUserProperties(dict: [String: Any], isHighPriority: Bool) { }
    func deleteUserProfile() { }

    func trackEvent(event: LoggableEvent) {
        lock.withLock { names.append(event.eventName) }
    }

    func trackScreenView(event: LoggableEvent) {
        lock.withLock { names.append(event.eventName) }
    }
}
