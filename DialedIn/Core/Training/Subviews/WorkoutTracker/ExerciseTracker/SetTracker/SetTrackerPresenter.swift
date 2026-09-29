//
//  SetTrackerPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 02/03/2026.
//

import SwiftUI

@Observable
@MainActor
class SetTrackerPresenter {
    private let interactor: SetTrackerInteractor
    private let router: SetTrackerRouter

    var showAutoRanges: Bool = true
    
    var exerciseUnitPreferences: [String: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)] = [:]
    /// What the user last did for each exercise, keyed by the exercise's `templateId`.
    var previousExercises: [String: WorkoutExerciseModel] = [:]
    var previousLookup: [PreviousSetKey: WorkoutSetModel] = [:]

    var userId: String? {
        interactor.userId
    }
    
    init(interactor: SetTrackerInteractor, router: SetTrackerRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onExerciseEquipmentPressed(_ exercise: Binding<WorkoutExerciseModel>) {
        let delegate = WorkoutExerciseEquipmentSheetDelegate(exercise: exercise) { variationId in
            exercise.wrappedValue.chosenVariationId = variationId
        }
        router.showWorkoutExerciseEquipmentSheetView(delegate: delegate)
    }
    
    func onWarmupSetsPressed(_ exercise: Binding<WorkoutExerciseModel>) {
        router.showWarmupSetsView(delegate: WarmupSetsDelegate(exercise: exercise))
    }
    
    func onExerciseSettingsPressed(exercise: WorkoutExerciseModel) {
        guard let exerciseModel = interactor.allExercises.first(where: { $0.id == exercise.templateId }) else { return }
        router.showExerciseSettingsView(delegate: ExerciseSettingsDelegate(exercise: exerciseModel))
    }

    func deleteExercise(_ exercise: Binding<WorkoutExerciseModel>, onDelete: @escaping @MainActor () -> Void) {
        let name = exercise.wrappedValue.name
        router.showAlert(title: String(localized: "Delete Exercise?"), subtitle: String(localized: "Remove '\(name)' from this workout?")) {
            AnyView(VStack(spacing: 8) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { onDelete() }
            })
        }
    }

    func onTargetsPressed(_ exercise: Binding<WorkoutExerciseModel>) {
        guard let model = interactor.allExercises.first(where: { $0.id == exercise.wrappedValue.templateId }) else { return }
        let adapted = Binding<WorkoutTemplateExercise>(
            get: { WorkoutTemplateExercise(exercise: model, setTargets: exercise.wrappedValue.setTargets, setRestTimers: false) },
            set: { exercise.wrappedValue.setTargets = $0.setTargets }
        )
        router.showSetTargetView(delegate: SetTargetDelegate(exercise: adapted))
    }

    func onSwapPressed(_ exercise: Binding<WorkoutExerciseModel>) {
        router.showSwapExercisePickerView { [weak self] newExercise in
            guard let self, let userId = self.interactor.userId else { return }
            let newMode = WorkoutSessionModel.trackingMode(for: newExercise)
            exercise.wrappedValue.templateId = newExercise.id
            exercise.wrappedValue.name = newExercise.name
            exercise.wrappedValue.trackingMode = newMode
            exercise.wrappedValue.equipmentVariations = newExercise.equipmentVariations
            exercise.wrappedValue.imageName = Constants.exerciseImageName(for: newExercise.name)
            exercise.wrappedValue.sets = WorkoutSessionModel.defaultSets(
                trackingMode: newMode,
                authorId: userId,
                targetCount: 3,
                perSide: WorkoutSessionModel.isPerSide(newExercise)
            )
            exercise.wrappedValue.setTargets = [SetTarget(setNumber: 1, setType: .standard)]
            exercise.wrappedValue.chosenVariationId = nil
        }
    }

    func onSupersetPressed(
        exercise: Binding<WorkoutExerciseModel>,
        allWorkoutExercises: [WorkoutExerciseModel],
        onSetSupersetGroup: @MainActor @escaping (String, String?) -> Void
    ) {
        let current = exercise.wrappedValue
        // Remove from existing group
        if let groupId = current.supersetGroupId {
            exercise.wrappedValue.supersetGroupId = nil
            let remaining = allWorkoutExercises.filter { $0.supersetGroupId == groupId && $0.id != current.id }
            // If only 1 remains, dissolve — a solo exercise can't be a superset
            if remaining.count == 1, let lastId = remaining.first?.id {
                onSetSupersetGroup(lastId, nil)
            }
            return
        }
        // No group — show all other exercises to pair with
        let available = allWorkoutExercises.filter { $0.id != current.id }
        guard !available.isEmpty else {
            router.showSimpleAlert(title: String(localized: "No Exercises Available"), subtitle: String(localized: "Add more exercises to create a superset or circuit."))
            return
        }
        router.showAlert(title: String(localized: "Add to Group"), subtitle: String(localized: "Pair '\(current.name)' with:")) {
            AnyView(VStack(spacing: 8) {
                ForEach(available, id: \.id) { partner in
                    let partnerGroupId = partner.supersetGroupId
                    let partnerId = partner.id
                    Button(partner.name) {
                        if let existingGroupId = partnerGroupId {
                            // Join the partner's existing group (builds a circuit)
                            exercise.wrappedValue.supersetGroupId = existingGroupId
                        } else {
                            // Create a new pair
                            let newGroupId = UUID().uuidString
                            exercise.wrappedValue.supersetGroupId = newGroupId
                            onSetSupersetGroup(partnerId, newGroupId)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            })
        }
    }

    func getUnitPreference(for exercise: WorkoutExerciseModel) -> (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit) {
        let templateId: String = exercise.templateId
        if let cached = exerciseUnitPreferences[templateId] {
            return cached
        }
        let preference = interactor.getPreference(templateId: templateId)
        let result = (weightUnit: preference.weightUnit, distanceUnit: preference.distanceUnit)
        exerciseUnitPreferences[templateId] = result
        return result
    }

    /// Deleting half of a left/right pair would leave the other half standing alone, numbering and
    /// resting as a set in its own right, so the pair goes together.
    func deleteSet(setId: String, exercise: Binding<WorkoutExerciseModel>) {
        let removing = Set(exercise.wrappedValue.sets.pairedSetIds(for: setId))
        guard !removing.isEmpty else { return }
        exercise.wrappedValue.sets.removeAll(where: { removing.contains($0.id) })
    }

    /// Adds one more set — which is two rows for an exercise worked a side at a time, so the user
    /// is never handed a left with no right to follow it.
    func addSet(exercise: Binding<WorkoutExerciseModel>) {
        guard let userId = interactor.userId else { return }
        let existingSets = exercise.wrappedValue.sets
        // One past the highest index, not one past the count. Deleting a set does not renumber the
        // rest, so after deleting any set but the last, the count no longer reaches the top index
        // and this handed the new set an index another set already held. Warmup sets share the
        // same numbering, which makes it easier still to hit.
        var nextIndex = (existingSets.map(\.index).max() ?? 0) + 1
        let sides: [SetSide?] = exercise.wrappedValue.isPerSide ? SetSide.ordered.map { $0 } : [nil]

        for side in sides {
            // Carry forward the figures of the last set on the same side, so a left set copies the
            // left arm's weight rather than the right one's.
            let lastSet = existingSets.last(where: { side == nil || $0.side == side }) ?? existingSets.last
            exercise.wrappedValue.sets.append(
                WorkoutSetModel(
                    id: UUID().uuidString,
                    authorId: userId,
                    index: nextIndex,
                    reps: lastSet?.reps,
                    weightKg: lastSet?.weightKg,
                    durationSec: lastSet?.durationSec,
                    distanceMeters: lastSet?.distanceMeters,
                    rpe: lastSet?.rpe,
                    side: side,
                    isWarmup: false,
                    completedAt: nil,
                    dateCreated: Date()
                )
            )
            nextIndex += 1
        }
    }

    func onWarmupSetHelpPressed() {
        router.showWarmupSetInfoModal {
            self.router.dismissModal()
        }
    }

    func buttonColor(set: WorkoutSetModel, canComplete: Bool) -> Color {
        if set.completedAt != nil {
            return .green
        } else if canComplete {
            return .secondary
        } else {
            return .red.opacity(0.6)
        }
    }

    func canComplete(trackingMode: TrackingMode, set: WorkoutSetModel) -> Bool {
        switch trackingMode {
        case .weightReps:
            let hasValidWeight = set.weightKg == nil || set.weightKg! >= 0
            let hasValidReps = set.reps != nil && set.reps! > 0
            return hasValidWeight && hasValidReps
        case .repsOnly:
            return set.reps != nil && set.reps! > 0
        case .timeOnly:
            return set.durationSec != nil && set.durationSec! > 0
        case .distanceTime:
            let hasValidDistance = set.distanceMeters != nil && set.distanceMeters! > 0
            let hasValidTime = set.durationSec != nil && set.durationSec! > 0
            return hasValidDistance && hasValidTime
        }
    }

    func validateSetData(trackingMode: TrackingMode, set: WorkoutSetModel) -> Bool {
        switch trackingMode {
        case .weightReps:
            if let weight = set.weightKg, weight < 0 {
                router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Weight must be a non-negative number"))
                return false
            }
            guard let reps = set.reps, reps > 0 else {
                router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Reps must be a positive number"))
                return false
            }
            return true
        case .repsOnly:
            guard let reps = set.reps, reps > 0 else {
                router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Reps must be a positive number"))
                return false
            }
            return true
        case .timeOnly:
            guard let duration = set.durationSec, duration > 0 else {
                router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Duration must be a positive time"))
                return false
            }
            return true
        case .distanceTime:
            guard let distance = set.distanceMeters, distance > 0 else {
                router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Distance must be a positive number"))
                return false
            }
            guard let duration = set.durationSec, duration > 0 else {
                router.showSimpleAlert(title: String(localized: "Invalid Set Data"), subtitle: String(localized: "Duration must be a positive time"))
                return false
            }
            return true
        }
    }

    func updateWeightUnit(_ unit: ExerciseWeightUnit, for exercise: Binding<WorkoutExerciseModel>) {
        let templateId: String = exercise.wrappedValue.templateId
        var current = getUnitPreference(for: exercise.wrappedValue)
        current.weightUnit = unit
        exerciseUnitPreferences[templateId] = current
        interactor.setWeightUnit(unit, for: templateId)
    }

    func convertAndRoundWeights(to newUnit: ExerciseWeightUnit, for exercise: Binding<WorkoutExerciseModel>) {
        let existingUnit = getUnitPreference(for: exercise.wrappedValue)
//        let currentUnit = existingUnit.weightUnit
        
        for set in exercise.sets {
            guard let weightKg = set.wrappedValue.weightKg else { continue }
            let weightInNewUnit = UnitConversion.convertWeight(weightKg, to: newUnit)
            let weightKgAsNewUnit = UnitConversion.convertWeightToKg(weightInNewUnit, from: newUnit)

            let exerciseTemplate = interactor.allExercises.first(where: { $0.id == exercise.wrappedValue.templateId })
            let roundedWeightKg = WorkoutSessionModel.roundWeightToEquipmentIncrement(
                weightKg: weightKgAsNewUnit,
                workoutExercise: exercise.wrappedValue,
                exerciseTemplate: exerciseTemplate,
                gymProfile: interactor.workoutGymProfile,
                preferredWeightUnit: newUnit
            )

            let roundedWeightKgFinal: Double
            if roundedWeightKg == weightKgAsNewUnit {
                let roundedWeight: Double
                if newUnit == .kilograms {
                    roundedWeight = round(weightInNewUnit * 2) / 2.0
                } else {
                    roundedWeight = round(weightInNewUnit)
                }
                roundedWeightKgFinal = UnitConversion.convertWeightToKg(roundedWeight, from: newUnit)
            } else {
                roundedWeightKgFinal = roundedWeightKg
            }

            set.wrappedValue.weightKg = roundedWeightKgFinal
        }
        exerciseUnitPreferences[exercise.wrappedValue.templateId] = (newUnit, existingUnit.distanceUnit)
        interactor.setWeightUnit(newUnit, for: exercise.wrappedValue.templateId)

    }

    /// Shows a prompt asking whether to just change display unit or convert values
    func promptWeightUnitChange(_ newUnit: ExerciseWeightUnit, for exercise: Binding<WorkoutExerciseModel>) {
        let currentUnit = getUnitPreference(for: exercise.wrappedValue).weightUnit
        guard newUnit != currentUnit else { return }

        router.showAlert(
            title: String(localized: "Change Weight Unit"),
            subtitle: String(localized: "How would you like to change the unit for '\(exercise.wrappedValue.name)'?"),
            buttons: {
                AnyView(
                    VStack(spacing: 8) {
                        Button("Display Only") {
                            self.updateWeightUnit(newUnit, for: exercise)
                        }
                        Button("Convert Values") {
                            self.convertAndRoundWeights(to: newUnit, for: exercise)
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    /// Shows a prompt asking whether to just change display unit or convert values
    func promptDistanceUnitChange(_ newUnit: ExerciseDistanceUnit, for exercise: Binding<WorkoutExerciseModel>) {
        let currentUnit = getUnitPreference(for: exercise.wrappedValue).distanceUnit
        guard newUnit != currentUnit else { return }

        router.showAlert(
            title: String(localized: "Change Distance Unit"),
            subtitle: String(localized: "How would you like to change the unit for '\(exercise.wrappedValue.name)'?"),
            buttons: {
                AnyView(
                    VStack(spacing: 8) {
                        Button("Display Only") {
                            self.updateDistanceUnit(newUnit, for: exercise)
                        }
                        Button("Convert Values") {
                            self.convertAndRoundDistances(to: newUnit, for: exercise)
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    func convertAndRoundDistances(to newUnit: ExerciseDistanceUnit, for exercise: Binding<WorkoutExerciseModel>) {
//        let currentUnit = getUnitPreference(for: exercise.wrappedValue).distanceUnit

        for set in exercise.sets {
            guard let distanceMeters = set.wrappedValue.distanceMeters else { continue }
            let distanceInNewUnit = UnitConversion.convertDistance(distanceMeters, to: newUnit)
            let roundedDistance: Double
            if newUnit == .meters {
                roundedDistance = round(distanceInNewUnit)
            } else {
                roundedDistance = round(distanceInNewUnit * 100) / 100.0
            }
            set.wrappedValue.distanceMeters = UnitConversion.convertDistanceToMeters(roundedDistance, from: newUnit)
        }
        updateDistanceUnit(newUnit, for: exercise)
    }

    func updateDistanceUnit(_ unit: ExerciseDistanceUnit, for exercise: Binding<WorkoutExerciseModel>) {
        let templateId: String = exercise.wrappedValue.templateId
        var current = getUnitPreference(for: exercise.wrappedValue)
        current.distanceUnit = unit
        exerciseUnitPreferences[templateId] = current
        interactor.setDistanceUnit(unit, for: templateId)
    }

    func buildPreviousLookup(for exercise: WorkoutExerciseModel) -> [PreviousSetKey: WorkoutSetModel] {
        guard let prevExercise = previousExercises[exercise.templateId] else { return [:] }
        
        // Map sets by index and side, keeping the last of any duplicates rather than trapping on
        // them. `Dictionary(uniqueKeysWithValues:)` crashes on a repeated key, and sessions saved
        // before `addSet` stopped reusing indices are still out there holding two sets numbered the
        // same — this is read when the exercise is next tracked, so such a session would take the
        // screen down every time it was opened.
        //
        // The side is part of the key because a left set showing the right arm's last weight is
        // worse than showing nothing: the user chases a number the other arm set.
        return Dictionary(
            prevExercise.sets.map { (PreviousSetKey($0), $0) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

}
