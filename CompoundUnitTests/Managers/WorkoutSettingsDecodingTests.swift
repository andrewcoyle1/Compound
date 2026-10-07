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

    /// The exercise strip is on unless switched off, including for every document saved before it.
    @Test("Test A Document Saved Before The Exercise Strip Reads As On")
    func testExerciseStripDefaultsToOn() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(WorkoutSettings(authorId: "author-1"))) as? [String: Any] ?? [:]
        json.removeValue(forKey: "show_exercise_strip")

        let decoded = try JSONDecoder().decode(WorkoutSettings.self, from: JSONSerialization.data(withJSONObject: json))

        #expect(decoded.showExerciseStrip == nil)
        #expect(decoded.showsExerciseStrip)
        #expect(WorkoutSettings(authorId: "author-1").showsExerciseStrip)
    }

    @Test("Test The Exercise Strip Choice Is Kept Through A Save", arguments: [true, false])
    func testExerciseStripRoundTrips(isOn: Bool) throws {
        var settings = WorkoutSettings(authorId: "author-1")
        settings.showExerciseStrip = isOn

        let decoded = try JSONDecoder().decode(WorkoutSettings.self, from: JSONEncoder().encode(settings))

        #expect(decoded.showExerciseStrip == isOn)
        #expect(decoded.showsExerciseStrip == isOn)
    }

    /// The set plan is off unless switched on, including for every document saved before it.
    @Test("Test A Document Saved Before The Set Plan Reads As Off")
    func testSetPlanningDefaultsToOff() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(WorkoutSettings(authorId: "author-1"))) as? [String: Any] ?? [:]
        json.removeValue(forKey: "set_planning")

        let decoded = try JSONDecoder().decode(WorkoutSettings.self, from: JSONSerialization.data(withJSONObject: json))

        #expect(decoded.setPlanning == nil)
        #expect(!decoded.plansSets)
        #expect(!WorkoutSettings(authorId: "author-1").plansSets)
    }

    @Test("Test The Set Plan Choice Is Kept Through A Save", arguments: [true, false])
    func testSetPlanningRoundTrips(isOn: Bool) throws {
        var settings = WorkoutSettings(authorId: "author-1")
        settings.setPlanning = isOn

        let decoded = try JSONDecoder().decode(WorkoutSettings.self, from: JSONEncoder().encode(settings))

        #expect(decoded.setPlanning == isOn)
        #expect(decoded.plansSets == isOn)
    }

    /// The per-kind rests within a set: 15, 20 and 15 seconds for a document saved before them,
    /// or the one intra-set rest such a document chose.
    @Test("Test A Document Saved Before The Per-Kind Intra-Set Rests Reads Their Defaults")
    func testPerKindIntraSetRestsDefault() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(WorkoutSettings(authorId: "author-1"))) as? [String: Any] ?? [:]
        for key in ["intra_set_rest_seconds", "intra_set_rest_myo_seconds", "intra_set_rest_pause_seconds", "intra_set_rest_cluster_seconds"] {
            json.removeValue(forKey: key)
        }

        var decoded = try JSONDecoder().decode(WorkoutSettings.self, from: JSONSerialization.data(withJSONObject: json))

        #expect(decoded.intraSetRestMyoSeconds == nil && decoded.intraSetRestPauseSeconds == nil && decoded.intraSetRestClusterSeconds == nil)
        #expect(decoded.intraSetRestMyo == 15 && decoded.intraSetRestPause == 20 && decoded.intraSetRestCluster == 15)

        json["intra_set_rest_seconds"] = 25
        decoded = try JSONDecoder().decode(WorkoutSettings.self, from: JSONSerialization.data(withJSONObject: json))

        #expect(decoded.intraSetRestMyo == 25 && decoded.intraSetRestPause == 25 && decoded.intraSetRestCluster == 25)
    }

    @Test("Test The Per-Kind Intra-Set Rests Are Kept Through A Save")
    func testPerKindIntraSetRestsRoundTrip() throws {
        var settings = WorkoutSettings(authorId: "author-1")
        settings.intraSetRestMyoSeconds = 10
        settings.intraSetRestPauseSeconds = 30
        settings.intraSetRestClusterSeconds = 12

        let decoded = try JSONDecoder().decode(WorkoutSettings.self, from: JSONEncoder().encode(settings))

        #expect(decoded.intraSetRestMyo == 10 && decoded.intraSetRestPause == 30 && decoded.intraSetRestCluster == 12)
        #expect(decoded.intraSetRest(for: .drop) == nil)
        #expect(decoded.intraSetRest(for: .restPause) == 30)
    }
}
