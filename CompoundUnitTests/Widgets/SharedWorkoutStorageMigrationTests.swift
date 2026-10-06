//
//  SharedWorkoutStorageMigrationTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// Moving the running rest and the started HealthKit session out of the store earlier builds
/// used (`group.com.dialedin.app`) into the App Group the entitlements grant.
@MainActor
struct SharedWorkoutStorageMigrationTests {

    private let restKey = "workout.rest.endTime"
    private let sessionKey = "workout.hk.started.sessionId"

    private func makeSuite() throws -> UserDefaults {
        let name = "SharedWorkoutStorageMigrationTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func copiesBothValuesOnceAndClearsLegacy() throws {
        let legacy = try makeSuite()
        let current = try makeSuite()
        legacy.set(1_000.0, forKey: restKey)
        legacy.set("session-1", forKey: sessionKey)

        SharedWorkoutStorage.migrateLegacy(from: legacy, to: current)

        #expect(current.double(forKey: restKey) == 1_000)
        #expect(current.string(forKey: sessionKey) == "session-1")
        #expect(legacy.object(forKey: restKey) == nil)
        #expect(legacy.object(forKey: sessionKey) == nil)

        // A second launch finds nothing to move and leaves the current store alone.
        current.set(2_000.0, forKey: restKey)
        SharedWorkoutStorage.migrateLegacy(from: legacy, to: current)
        #expect(current.double(forKey: restKey) == 2_000)
        #expect(current.string(forKey: sessionKey) == "session-1")
    }

    @Test func keepsCurrentValuesAndStillClearsLegacy() throws {
        let legacy = try makeSuite()
        let current = try makeSuite()
        legacy.set(1_000.0, forKey: restKey)
        legacy.set("old", forKey: sessionKey)
        current.set(5_000.0, forKey: restKey)
        current.set("new", forKey: sessionKey)

        SharedWorkoutStorage.migrateLegacy(from: legacy, to: current)

        #expect(current.double(forKey: restKey) == 5_000)
        #expect(current.string(forKey: sessionKey) == "new")
        #expect(legacy.object(forKey: restKey) == nil)
        #expect(legacy.object(forKey: sessionKey) == nil)
    }

    @Test func emptyLegacyChangesNothing() throws {
        let legacy = try makeSuite()
        let current = try makeSuite()

        SharedWorkoutStorage.migrateLegacy(from: legacy, to: current)

        #expect(current.object(forKey: restKey) == nil)
        #expect(current.object(forKey: sessionKey) == nil)
    }
}
