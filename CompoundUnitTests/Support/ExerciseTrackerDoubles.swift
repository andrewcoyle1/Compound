//
//  ExerciseTrackerDoubles.swift
//  CompoundUnitTests
//
//  The exercise tracker's interactor and router doubles, shared by its presenter's suites.
//

import SwiftUI
@testable import Compound

final class ExerciseTrackerInteractorDouble: SpyGlobalInteractor, ExerciseTrackerInteractor {
    var userId: String? = "user-1"
    var allExercises: [ExerciseModel] = []
    var workoutGymProfile: GymProfileModel?

    var preferences: [String: ExerciseUnitPreference] = [:]
    private(set) var savedWeightUnits: [(String, ExerciseWeightUnit)] = []
    private(set) var savedDistanceUnits: [(String, ExerciseDistanceUnit)] = []

    /// Exercise notes by template id, and every note saved.
    var notes: [String: String] = [:]
    private(set) var savedNotes: [String?] = []

    func getPreference(templateId: String) -> ExerciseUnitPreference {
        preferences[templateId] ?? ExerciseUnitPreference(exerciseModelId: templateId)
    }

    /// Stores the unit as the manager does, as well as recording the call.
    func setWeightUnit(_ unit: ExerciseWeightUnit, for templateId: String) {
        savedWeightUnits.append((templateId, unit))
        preferences[templateId, default: ExerciseUnitPreference(exerciseModelId: templateId)].weightUnit = unit
    }

    func setDistanceUnit(_ unit: ExerciseDistanceUnit, for templateId: String) {
        savedDistanceUnits.append((templateId, unit))
        preferences[templateId, default: ExerciseUnitPreference(exerciseModelId: templateId)].distanceUnit = unit
    }

    func exerciseNote(for exerciseId: String) -> String? {
        notes[exerciseId]
    }

    func setExerciseNote(_ note: String?, for exerciseId: String) async throws {
        savedNotes.append(note)
    }
}

/// The alerts this screen raises — delete, superset, unit change — go through
/// `showAlert(title:subtitle:buttons:)` and `showSimpleAlert`, `GlobalRouter` extensions that
/// dispatch statically and never reach this double, so tests assert the state that is reachable.
final class ExerciseTrackerRouterDouble: ExerciseTrackerRouter {
    let router: AnyRouter = TestRouting.anyRouter
    private(set) var shown: [String] = []
    /// Handed back by the swap picker when set, standing in for the user picking.
    var swapSelection: ExerciseModel?
    private(set) var delegates: [WorkoutNotesDelegate] = []
    private(set) var confirmations: [String] = []

    func showWorkoutNotesView(delegate: WorkoutNotesDelegate) {
        delegates.append(delegate)
    }

    func showWorkoutExerciseEquipmentSheetView(delegate: WorkoutExerciseEquipmentSheetDelegate) {
        shown.append("equipment")
    }

    func showExerciseSettingsView(delegate: ExerciseSettingsDelegate) {
        shown.append("exerciseSettings")
    }

    func showSetTargetView(delegate: SetTargetDelegate) {
        shown.append("setTarget")
    }

    func showSwapExercisePickerView(alternativeIds: [String], onSelect: @escaping (ExerciseModel) -> Void) {
        shown.append("swapPicker")
        if let swapSelection {
            onSelect(swapSelection)
        }
    }

    /// A requirement of `GlobalRouter`, so unlike the alerts it does reach this double.
    func showConfirmationDialog(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
        confirmations.append(title)
    }
}
