//
//  WorkoutSettingsDecodingTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// Settings added after release decode from documents saved before them.
struct WorkoutSettingsDecodingTests {

    /// "Rest between superset partners": none unless chosen, including for every document saved
    /// before the setting existed.
    @Test("Test A Document Saved Before The Superset Transition Rest Reads As None")
    func testSupersetTransitionRestDefaultsToNone() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(WorkoutSettings(authorId: "author-1"))) as? [String: Any] ?? [:]
        json.removeValue(forKey: "superset_transition_rest_seconds")

        let decoded = try JSONDecoder().decode(WorkoutSettings.self, from: JSONSerialization.data(withJSONObject: json))

        #expect(decoded.supersetTransitionRestSeconds == nil)
        #expect(WorkoutSettings(authorId: "author-1").supersetTransitionRestSeconds == nil)
    }

    @Test("Test A Superset Transition Rest Is Kept Through A Save")
    func testSupersetTransitionRestRoundTrips() throws {
        var settings = WorkoutSettings(authorId: "author-1")
        settings.supersetTransitionRestSeconds = 30

        let decoded = try JSONDecoder().decode(WorkoutSettings.self, from: JSONEncoder().encode(settings))

        #expect(decoded.supersetTransitionRestSeconds == 30)
    }

    /// The breath between mini-sets: 15 seconds unless chosen, including for every document saved
    /// before the setting existed.
    @Test("Test A Document Saved Before The Intra-Set Rest Reads As Fifteen Seconds")
    func testIntraSetRestDefaultsToFifteen() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(WorkoutSettings(authorId: "author-1"))) as? [String: Any] ?? [:]
        json.removeValue(forKey: "intra_set_rest_seconds")

        let decoded = try JSONDecoder().decode(WorkoutSettings.self, from: JSONSerialization.data(withJSONObject: json))

        #expect(decoded.intraSetRestSeconds == nil)
        #expect(decoded.intraSetRest == 15)
    }

    @Test("Test An Intra-Set Rest Is Kept Through A Save")
    func testIntraSetRestRoundTrips() throws {
        var settings = WorkoutSettings(authorId: "author-1")
        settings.intraSetRestSeconds = 20

        let decoded = try JSONDecoder().decode(WorkoutSettings.self, from: JSONEncoder().encode(settings))

        #expect(decoded.intraSetRest == 20)
    }
}
