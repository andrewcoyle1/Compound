//
//  ExerciseUnitPreferenceManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 28/10/2025.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct ExerciseUnitPreferenceManagerTests {
    
    // MARK: - Helper Methods
    
    /// A manager over its own empty `UserDefaults`, reading the defaults of a signed-in user.
    /// `UserManager` now holds its user in a sync engine, which only has one once it is listening,
    /// so the sign-in is what puts `user` behind `currentUser`.
    private func createManager(user: UserModel? = nil) async throws -> (ExerciseUnitPreferenceManager, UserDefaults) {
        let userDefaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let manager = try await ExerciseUnitPreferenceManager(
            userDefaults: userDefaults,
            userManager: TestManagers.signedInUserManager(user)
        )
        return (manager, userDefaults)
    }

    /// A second manager over storage a first one already wrote to, for checking that a preference
    /// was persisted rather than only cached.
    private func reopenManager(
        userDefaults: UserDefaults,
        user: UserModel?
    ) async throws -> ExerciseUnitPreferenceManager {
        try await ExerciseUnitPreferenceManager(
            userDefaults: userDefaults,
            userManager: TestManagers.signedInUserManager(user)
        )
    }
    
    private func createUserWithPreferences(
        weightUnit: WeightUnitPreference,
        lengthUnit: LengthUnitPreference
    ) -> UserModel {
        UserModel(
            userId: "testUser123",
            email: "test@example.com",
            submittedLengthUnitPreference: lengthUnit,
            submittedWeightUnitPreference: weightUnit
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test("Test Initialization With Default User Defaults")
    func testInitializationWithDefaultUserDefaults() async throws {
        let manager = ExerciseUnitPreferenceManager(
            userManager: try await TestManagers.signedInUserManager(UserModel.mock)
        )
        
        // Manager should be initialized successfully
        let preference = manager.getPreference(for: "test-template")
        #expect(preference.exerciseModelId == "test-template")
    }
    
    @Test("Test Initialization With Custom User Defaults")
    func testInitializationWithCustomUserDefaults() async throws {
        // A suite of its own: a fixed name is a file on the simulator that outlives the run and is
        // shared with anything else building against the same simulator.
        let customDefaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let manager = try await reopenManager(userDefaults: customDefaults, user: UserModel.mock)
        
        let preference = manager.getPreference(for: "test-template")
        #expect(preference.exerciseModelId == "test-template")
    }
    
    // MARK: - Get Preference Tests
    
    @Test("Test Get Preference Returns Default When No Saved Preference")
    func testGetPreferenceReturnsDefaultWhenNoSavedPreference() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        let preference = manager.getPreference(for: "template1")
        
        #expect(preference.exerciseModelId == "template1")
        #expect(preference.weightUnit == .kilograms)
        #expect(preference.distanceUnit == .meters)
    }
    
    @Test("Test Get Preference Uses User Weight Preference For Default")
    func testGetPreferenceUsesUserWeightPreferenceForDefault() async throws {
        let user = createUserWithPreferences(weightUnit: .pounds, lengthUnit: .inches)
        let (manager, _) = try await createManager(user: user)
        
        let preference = manager.getPreference(for: "template1")
        
        #expect(preference.weightUnit == .pounds)
    }
    
    @Test("Test Get Preference Uses User Length Preference For Default Distance")
    func testGetPreferenceUsesUserLengthPreferenceForDefaultDistance() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .inches)
        let (manager, _) = try await createManager(user: user)
        
        let preference = manager.getPreference(for: "template1")
        
        #expect(preference.distanceUnit == .miles)
    }
    
    @Test("Test Get Preference Returns Kilograms When User Has No Weight Preference")
    func testGetPreferenceReturnsKilogramsWhenUserHasNoWeightPreference() async throws {
        let user = UserModel(userId: "testUser")
        let (manager, _) = try await createManager(user: user)
        
        let preference = manager.getPreference(for: "template1")
        
        #expect(preference.weightUnit == .kilograms)
    }
    
    @Test("Test Get Preference Returns Meters When User Has No Length Preference")
    func testGetPreferenceReturnsMetersWhenUserHasNoLengthPreference() async throws {
        let user = UserModel(userId: "testUser")
        let (manager, _) = try await createManager(user: user)
        
        let preference = manager.getPreference(for: "template1")
        
        #expect(preference.distanceUnit == .meters)
    }
    
    @Test("Test Get Preference Returns Cached Value On Second Call")
    func testGetPreferenceReturnsCachedValueOnSecondCall() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        let preference1 = manager.getPreference(for: "template1")
        let preference2 = manager.getPreference(for: "template1")
        
        #expect(preference1.exerciseModelId == preference2.exerciseModelId)
        #expect(preference1.weightUnit == preference2.weightUnit)
        #expect(preference1.distanceUnit == preference2.distanceUnit)
    }
    
    @Test("Test Get Preference Loads From User Defaults When Available")
    func testGetPreferenceLoadsFromUserDefaultsWhenAvailable() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (_, userDefaults) = try await createManager(user: user)
        
        // Manually save a preference to UserDefaults
        let savedPreference = ExerciseUnitPreference(
            exerciseModelId: "template1",
            weightUnit: .pounds,
            distanceUnit: .miles
        )
        let key = "exercise_unit_preference_testUser123_template1"
        if let data = try? JSONEncoder().encode(savedPreference) {
            userDefaults.set(data, forKey: key)
        }
        
        // Create a new manager instance to avoid cache
        let newManager = try await reopenManager(userDefaults: userDefaults, user: user)
        let preference = newManager.getPreference(for: "template1")
        
        #expect(preference.weightUnit == .pounds)
        #expect(preference.distanceUnit == .miles)
    }
    
    @Test("Test Get Preference For Different Templates Returns Different Preferences")
    func testGetPreferenceForDifferentTemplatesReturnsDifferentPreferences() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        let preference1 = manager.getPreference(for: "template1")
        let preference2 = manager.getPreference(for: "template2")
        
        #expect(preference1.exerciseModelId == "template1")
        #expect(preference2.exerciseModelId == "template2")
    }
    
    // MARK: - Set Weight Unit Tests
    
    @Test("Test Set Weight Unit Updates Preference")
    func testSetWeightUnitUpdatesPreference() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        manager.setWeightUnit(.pounds, for: "template1")
        
        let preference = manager.getPreference(for: "template1")
        #expect(preference.weightUnit == .pounds)
    }
    
    @Test("Test Set Weight Unit Persists To User Defaults")
    func testSetWeightUnitPersistsToUserDefaults() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, userDefaults) = try await createManager(user: user)
        
        manager.setWeightUnit(.pounds, for: "template1")
        
        // Create new manager to verify persistence
        let newManager = try await reopenManager(userDefaults: userDefaults, user: user)
        let preference = newManager.getPreference(for: "template1")
        
        #expect(preference.weightUnit == .pounds)
    }
    
    @Test("Test Set Weight Unit Does Not Affect Distance Unit")
    func testSetWeightUnitDoesNotAffectDistanceUnit() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .inches)
        let (manager, _) = try await createManager(user: user)
        
        let originalPreference = manager.getPreference(for: "template1")
        manager.setWeightUnit(.pounds, for: "template1")
        let updatedPreference = manager.getPreference(for: "template1")
        
        #expect(updatedPreference.distanceUnit == originalPreference.distanceUnit)
    }
    
    @Test("Test Set Weight Unit For Multiple Templates")
    func testSetWeightUnitForMultipleTemplates() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        manager.setWeightUnit(.pounds, for: "template1")
        manager.setWeightUnit(.kilograms, for: "template2")
        
        let preference1 = manager.getPreference(for: "template1")
        let preference2 = manager.getPreference(for: "template2")
        
        #expect(preference1.weightUnit == .pounds)
        #expect(preference2.weightUnit == .kilograms)
    }
    
    @Test("Test Set Weight Unit Overwrites Previous Value")
    func testSetWeightUnitOverwritesPreviousValue() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        manager.setWeightUnit(.pounds, for: "template1")
        manager.setWeightUnit(.kilograms, for: "template1")
        
        let preference = manager.getPreference(for: "template1")
        #expect(preference.weightUnit == .kilograms)
    }
    
    // MARK: - Set Distance Unit Tests
    
    @Test("Test Set Distance Unit Updates Preference")
    func testSetDistanceUnitUpdatesPreference() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        manager.setDistanceUnit(.miles, for: "template1")
        
        let preference = manager.getPreference(for: "template1")
        #expect(preference.distanceUnit == .miles)
    }
    
    @Test("Test Set Distance Unit Persists To User Defaults")
    func testSetDistanceUnitPersistsToUserDefaults() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, userDefaults) = try await createManager(user: user)
        
        manager.setDistanceUnit(.miles, for: "template1")
        
        // Create new manager to verify persistence
        let newManager = try await reopenManager(userDefaults: userDefaults, user: user)
        let preference = newManager.getPreference(for: "template1")
        
        #expect(preference.distanceUnit == .miles)
    }
    
    @Test("Test Set Distance Unit Does Not Affect Weight Unit")
    func testSetDistanceUnitDoesNotAffectWeightUnit() async throws {
        let user = createUserWithPreferences(weightUnit: .pounds, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        let originalPreference = manager.getPreference(for: "template1")
        manager.setDistanceUnit(.miles, for: "template1")
        let updatedPreference = manager.getPreference(for: "template1")
        
        #expect(updatedPreference.weightUnit == originalPreference.weightUnit)
    }
    
    @Test("Test Set Distance Unit For Multiple Templates")
    func testSetDistanceUnitForMultipleTemplates() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        manager.setDistanceUnit(.miles, for: "template1")
        manager.setDistanceUnit(.meters, for: "template2")
        
        let preference1 = manager.getPreference(for: "template1")
        let preference2 = manager.getPreference(for: "template2")
        
        #expect(preference1.distanceUnit == .miles)
        #expect(preference2.distanceUnit == .meters)
    }
    
    @Test("Test Set Distance Unit Overwrites Previous Value")
    func testSetDistanceUnitOverwritesPreviousValue() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        manager.setDistanceUnit(.miles, for: "template1")
        manager.setDistanceUnit(.meters, for: "template1")
        
        let preference = manager.getPreference(for: "template1")
        #expect(preference.distanceUnit == .meters)
    }
    
    // MARK: - Set Preference (Both Units) Tests
    
    @Test("Test Set Preference Updates Both Units")
    func testSetPreferenceUpdatesBothUnits() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        manager.setPreference(weightUnit: .pounds, distanceUnit: .miles, for: "template1")
        
        let preference = manager.getPreference(for: "template1")
        #expect(preference.weightUnit == .pounds)
        #expect(preference.distanceUnit == .miles)
    }
    
    @Test("Test Set Preference Updates Only Weight Unit When Distance Unit Is Nil")
    func testSetPreferenceUpdatesOnlyWeightUnitWhenDistanceUnitIsNil() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        let originalPreference = manager.getPreference(for: "template1")
        manager.setPreference(weightUnit: .pounds, distanceUnit: nil, for: "template1")
        let updatedPreference = manager.getPreference(for: "template1")
        
        #expect(updatedPreference.weightUnit == .pounds)
        #expect(updatedPreference.distanceUnit == originalPreference.distanceUnit)
    }
    
    @Test("Test Set Preference Updates Only Distance Unit When Weight Unit Is Nil")
    func testSetPreferenceUpdatesOnlyDistanceUnitWhenWeightUnitIsNil() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        let originalPreference = manager.getPreference(for: "template1")
        manager.setPreference(weightUnit: nil, distanceUnit: .miles, for: "template1")
        let updatedPreference = manager.getPreference(for: "template1")
        
        #expect(updatedPreference.weightUnit == originalPreference.weightUnit)
        #expect(updatedPreference.distanceUnit == .miles)
    }
    
    @Test("Test Set Preference Does Not Update When Both Parameters Are Nil")
    func testSetPreferenceDoesNotUpdateWhenBothParametersAreNil() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        let originalPreference = manager.getPreference(for: "template1")
        manager.setPreference(weightUnit: nil, distanceUnit: nil, for: "template1")
        let updatedPreference = manager.getPreference(for: "template1")
        
        #expect(updatedPreference.weightUnit == originalPreference.weightUnit)
        #expect(updatedPreference.distanceUnit == originalPreference.distanceUnit)
    }
    
    @Test("Test Set Preference Persists To User Defaults")
    func testSetPreferencePersistsToUserDefaults() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, userDefaults) = try await createManager(user: user)
        
        manager.setPreference(weightUnit: .pounds, distanceUnit: .miles, for: "template1")
        
        // Create new manager to verify persistence
        let newManager = try await reopenManager(userDefaults: userDefaults, user: user)
        let preference = newManager.getPreference(for: "template1")
        
        #expect(preference.weightUnit == .pounds)
        #expect(preference.distanceUnit == .miles)
    }
    
    // MARK: - Clear Cache Tests
    
    @Test("Test Clear Cache Removes Cached Preferences")
    func testClearCacheRemovesCachedPreferences() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        // Get preference to populate cache
        _ = manager.getPreference(for: "template1")
        
        // Set a custom preference
        manager.setWeightUnit(.pounds, for: "template1")
        
        // Clear cache
        manager.clearCache()
        
        // Get preference again - should reload from UserDefaults
        let preference = manager.getPreference(for: "template1")
        #expect(preference.weightUnit == .pounds)
    }
    
    @Test("Test Clear Cache Does Not Affect Persisted Data")
    func testClearCacheDoesNotAffectPersistedData() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, userDefaults) = try await createManager(user: user)
        
        manager.setPreference(weightUnit: .pounds, distanceUnit: .miles, for: "template1")
        manager.clearCache()
        
        // Create new manager to verify persistence
        let newManager = try await reopenManager(userDefaults: userDefaults, user: user)
        let preference = newManager.getPreference(for: "template1")
        
        #expect(preference.weightUnit == .pounds)
        #expect(preference.distanceUnit == .miles)
    }
    
    @Test("Test Clear Cache With Multiple Templates")
    func testClearCacheWithMultipleTemplates() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        manager.setWeightUnit(.pounds, for: "template1")
        manager.setWeightUnit(.kilograms, for: "template2")
        
        manager.clearCache()
        
        // Preferences should still be available from UserDefaults
        let preference1 = manager.getPreference(for: "template1")
        let preference2 = manager.getPreference(for: "template2")
        
        #expect(preference1.weightUnit == .pounds)
        #expect(preference2.weightUnit == .kilograms)
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("Test Get Preference With No User Returns Default Values")
    func testGetPreferenceWithNoUserReturnsDefaultValues() async throws {
        let (manager, _) = try await createManager(user: nil)
        
        let preference = manager.getPreference(for: "template1")
        
        #expect(preference.exerciseModelId == "template1")
        #expect(preference.weightUnit == .kilograms)
        #expect(preference.distanceUnit == .meters)
    }
    
    @Test("Test Set Weight Unit With No User Does Not Save")
    func testSetWeightUnitWithNoUserDoesNotSave() async throws {
        let (manager, userDefaults) = try await createManager(user: nil)
        
        manager.setWeightUnit(.pounds, for: "template1")
        
        // Verify nothing was saved to UserDefaults
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let hasPreferenceKey = allKeys.contains { $0.contains("exercise_unit_preference") }
        #expect(hasPreferenceKey == false)
    }
    
    @Test("Test Set Distance Unit With No User Does Not Save")
    func testSetDistanceUnitWithNoUserDoesNotSave() async throws {
        let (manager, userDefaults) = try await createManager(user: nil)
        
        manager.setDistanceUnit(.miles, for: "template1")
        
        // Verify nothing was saved to UserDefaults
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let hasPreferenceKey = allKeys.contains { $0.contains("exercise_unit_preference") }
        #expect(hasPreferenceKey == false)
    }
    
    @Test("Test Get Preference With Empty Template ID")
    func testGetPreferenceWithEmptyTemplateId() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        let preference = manager.getPreference(for: "")
        
        #expect(preference.exerciseModelId == "")
    }
    
    @Test("Test Set Weight Unit With Special Characters In Template ID")
    func testSetWeightUnitWithSpecialCharactersInTemplateId() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        let specialId = "template-123_test@example.com"
        manager.setWeightUnit(.pounds, for: specialId)
        
        let preference = manager.getPreference(for: specialId)
        #expect(preference.weightUnit == .pounds)
    }
    
    @Test("Test Concurrent Get Preference Calls")
    func testConcurrentGetPreferenceCalls() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        let preference1 = manager.getPreference(for: "template1")
        let preference2 = manager.getPreference(for: "template1")
        let preference3 = manager.getPreference(for: "template1")
        
        #expect(preference1.weightUnit == preference2.weightUnit)
        #expect(preference2.weightUnit == preference3.weightUnit)
    }
    
    @Test("Test Multiple Set Operations On Same Template")
    func testMultipleSetOperationsOnSameTemplate() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        manager.setWeightUnit(.pounds, for: "template1")
        manager.setDistanceUnit(.miles, for: "template1")
        manager.setWeightUnit(.kilograms, for: "template1")
        
        let preference = manager.getPreference(for: "template1")
        #expect(preference.weightUnit == .kilograms)
        #expect(preference.distanceUnit == .miles)
    }
    
    // MARK: - Unit Mapping Tests
    
    @Test("Test Centimeters Maps To Meters")
    func testCentimetersMapsToMeters() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        let preference = manager.getPreference(for: "template1")
        #expect(preference.distanceUnit == .meters)
    }
    
    @Test("Test Inches Maps To Miles")
    func testInchesMapsToMiles() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .inches)
        let (manager, _) = try await createManager(user: user)
        
        let preference = manager.getPreference(for: "template1")
        #expect(preference.distanceUnit == .miles)
    }
    
    @Test("Test Kilograms Maps To Kilograms")
    func testKilogramsMapsToKilograms() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        let preference = manager.getPreference(for: "template1")
        #expect(preference.weightUnit == .kilograms)
    }
    
    @Test("Test Pounds Maps To Pounds")
    func testPoundsMapsToLounds() async throws {
        let user = createUserWithPreferences(weightUnit: .pounds, lengthUnit: .centimeters)
        let (manager, _) = try await createManager(user: user)
        
        let preference = manager.getPreference(for: "template1")
        #expect(preference.weightUnit == .pounds)
    }
    
    // MARK: - Persistence Key Tests
    
    @Test("Test Preference Key Format Is Correct")
    func testPreferenceKeyFormatIsCorrect() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let (manager, userDefaults) = try await createManager(user: user)
        
        manager.setWeightUnit(.pounds, for: "template1")
        
        let expectedKey = "exercise_unit_preference_testUser123_template1"
        let data = userDefaults.data(forKey: expectedKey)
        
        #expect(data != nil)
    }
    
    @Test("Test Different Users Have Different Preference Keys")
    func testDifferentUsersHaveDifferentPreferenceKeys() async throws {
        let user1 = UserModel(userId: "user1", submittedLengthUnitPreference: .centimeters, submittedWeightUnitPreference: .kilograms)
        let user2 = UserModel(userId: "user2", submittedLengthUnitPreference: .inches, submittedWeightUnitPreference: .pounds)
        
        let userDefaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        
        let manager1 = try await reopenManager(userDefaults: userDefaults, user: user1)
        let manager2 = try await reopenManager(userDefaults: userDefaults, user: user2)
        
        manager1.setWeightUnit(.pounds, for: "template1")
        manager2.setWeightUnit(.kilograms, for: "template1")
        
        let preference1 = manager1.getPreference(for: "template1")
        let preference2 = manager2.getPreference(for: "template1")
        
        #expect(preference1.weightUnit == .pounds)
        #expect(preference2.weightUnit == .kilograms)
    }
    
    @Test("Test Preferences Persist Across Manager Instances")
    func testPreferencesPersistAcrossManagerInstances() async throws {
        let user = createUserWithPreferences(weightUnit: .kilograms, lengthUnit: .centimeters)
        let userDefaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        
        let manager1 = try await reopenManager(userDefaults: userDefaults, user: user)
        manager1.setPreference(weightUnit: .pounds, distanceUnit: .miles, for: "template1")
        
        let manager2 = try await reopenManager(userDefaults: userDefaults, user: user)
        let preference = manager2.getPreference(for: "template1")
        
        #expect(preference.weightUnit == .pounds)
        #expect(preference.distanceUnit == .miles)
    }
}
