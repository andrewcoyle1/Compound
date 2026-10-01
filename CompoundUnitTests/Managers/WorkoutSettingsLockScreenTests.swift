//
//  WorkoutSettingsLockScreenTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// "Show on Lock Screen": on by default, including for everyone whose settings were saved before
/// the switch existed, and off when turned off.
struct WorkoutSettingsLockScreenTests {

    @Test("Test Show On Lock Screen Is On By Default")
    func testShowOnLockScreenIsOnByDefault() {
        #expect(WorkoutSettings(authorId: "author-1").showsOnLockScreen)
    }

    /// A document saved before the field existed must still decode, and read as on.
    @Test("Test A Document Saved Before The Setting Existed Reads As On")
    func testADocumentSavedBeforeTheSettingExistedReadsAsOn() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(WorkoutSettings(authorId: "author-1"))) as? [String: Any] ?? [:]
        json.removeValue(forKey: "show_on_lock_screen")
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(WorkoutSettings.self, from: data)

        #expect(decoded.showsOnLockScreen)
    }

    @Test("Test Turning It Off Is Kept Through A Save")
    func testTurningItOffIsKeptThroughASave() throws {
        var settings = WorkoutSettings(authorId: "author-1")
        settings.showOnLockScreen = false

        let decoded = try JSONDecoder().decode(WorkoutSettings.self, from: JSONEncoder().encode(settings))

        #expect(!decoded.showsOnLockScreen)
    }
}
