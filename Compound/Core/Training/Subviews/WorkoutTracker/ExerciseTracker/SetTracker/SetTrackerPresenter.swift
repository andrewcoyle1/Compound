//
//  SetTrackerPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 02/03/2026.
//

import SwiftUI

@Observable
@MainActor
class SetTrackerPresenter {
    private let interactor: SetTrackerInteractor
    private let router: SetTrackerRouter

    /// Last session by default; Auto shows smart progression's suggestion for each set instead.
    /// Kept on the device, so the column a user switched to is the one they get next time. The
    /// redesign changed the default from Auto: users who never switched now get Last too, since
    /// the Auto figures are already in the rows.
    var showAutoRanges: Bool {
        didSet { defaults.set(showAutoRanges, forKey: Self.showAutoRangesKey) }
    }
    private let defaults: UserDefaults
    static let showAutoRangesKey = "SetTracker.showsSuggestions"
    
    /// What the user last did for each exercise, keyed by the exercise's `templateId`.
    var previousExercises: [String: WorkoutExerciseModel] = [:]
    var previousLookup: [PreviousSetKey: WorkoutSetModel] = [:]

    var userId: String? {
        interactor.userId
    }
    
    init(interactor: SetTrackerInteractor, router: SetTrackerRouter, defaults: UserDefaults = .standard) {
        self.interactor = interactor
        self.router = router
        self.defaults = defaults
        self.showAutoRanges = defaults.object(forKey: Self.showAutoRangesKey) as? Bool ?? false
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
            AnyView(VStack(spacing: Spacing.s) {
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

    /// Logged sets move to the replacement when it is measured the same way, so a swap mid-exercise
    /// keeps what was done. When it is not, they cannot, and the person is asked before they go.
    func onSwapPressed(_ exercise: Binding<WorkoutExerciseModel>) {
        router.showSwapExercisePickerView { [weak self] newExercise in
            guard let self else { return }
            let current = exercise.wrappedValue
            let hasLoggedSets = current.sets.contains { $0.completedAt != nil }
            let measuredAlike = current.trackingMode == WorkoutSessionModel.trackingMode(for: newExercise)
                && current.isPerSide == WorkoutSessionModel.isPerSide(newExercise)
            guard hasLoggedSets, !measuredAlike else {
                return self.swap(exercise, to: newExercise, keepingLoggedSets: hasLoggedSets)
            }
            self.router.showConfirmationDialog(
                title: String(localized: "Discard Logged Sets?"),
                subtitle: String(localized: "\(newExercise.name) is measured differently, so the sets logged for \(current.name) can't move to it."),
                buttons: {
                    AnyView(VStack(spacing: Spacing.s) {
                        Button("Swap and Discard Sets", role: .destructive) {
                            self.swap(exercise, to: newExercise, keepingLoggedSets: false)
                        }
                        Button("Cancel", role: .cancel) { }
                    })
                }
            )
        }
    }

    /// The sets not yet logged are replaced by fresh ones, as many as there were open (three when
    /// nothing was logged), so a swap leaves the workout the same length.
    func swap(_ exercise: Binding<WorkoutExerciseModel>, to newExercise: ExerciseModel, keepingLoggedSets: Bool) {
        guard let userId = interactor.userId else { return }
        let newMode = WorkoutSessionModel.trackingMode(for: newExercise)
        let logged = keepingLoggedSets ? exercise.wrappedValue.sets.filter { $0.completedAt != nil } : []
        let openCount = exercise.wrappedValue.sets.filter { $0.completedAt == nil }.pairedSetCount
        let fresh = logged.isEmpty || openCount > 0
            ? WorkoutSessionModel.defaultSets(
                trackingMode: newMode,
                authorId: userId,
                targetCount: logged.isEmpty ? 3 : openCount,
                perSide: WorkoutSessionModel.isPerSide(newExercise)
            )
            : []
        var sets = logged + fresh
        for index in sets.indices { sets[index].index = index + 1 }
        // Kept split if it was, so the fresh rows match the logged pairs above them.
        if exercise.wrappedValue.isSplit && !logged.isEmpty { sets = sets.splittingSides() }

        exercise.wrappedValue.templateId = newExercise.id
        exercise.wrappedValue.name = newExercise.name
        exercise.wrappedValue.trackingMode = newMode
        exercise.wrappedValue.equipmentVariations = newExercise.equipmentVariations
        exercise.wrappedValue.imageName = Constants.exerciseImageName(for: newExercise)
        exercise.wrappedValue.sets = sets
        exercise.wrappedValue.setTargets = [SetTarget(setNumber: 1, setType: .standard)]
        exercise.wrappedValue.chosenVariationId = nil
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
            AnyView(VStack(spacing: Spacing.s) {
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

    /// Read from `ExerciseUnitPreferenceManager` every time. Each presenter used to keep its own
    /// copy, and a row's copy outlived a switch to pounds: the header said lb while the keypad
    /// still converted from kg, so a typed 50 lb was stored as 50 kg.
    func getUnitPreference(for exercise: WorkoutExerciseModel) -> (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit) {
        let preference = interactor.getPreference(templateId: exercise.templateId)
        return (weightUnit: preference.weightUnit, distanceUnit: preference.distanceUnit)
    }

    /// Deleting half of a left/right pair would leave the other half standing alone, numbering and
    /// resting as a set in its own right, so the pair goes together.
    func deleteSet(setId: String, exercise: Binding<WorkoutExerciseModel>) {
        let removing = Set(exercise.wrappedValue.sets.pairedSetIds(for: setId))
        guard !removing.isEmpty else { return }
        exercise.wrappedValue.sets.removeAll(where: { removing.contains($0.id) })
    }

    /// Logs each side as its own row, or both sides as one again. Joining keeps the left side's
    /// figures; the chip that calls this only shows for an exercise worked a side at a time.
    func onSplitSidesPressed(_ exercise: Binding<WorkoutExerciseModel>) {
        let sets = exercise.wrappedValue.sets
        exercise.wrappedValue.sets = exercise.wrappedValue.isSplit ? sets.joiningSides() : sets.splittingSides()
        interactor.playHaptic(option: .selection)
    }

    /// Adds one more set — which is two rows for an exercise whose sides are split, so the user
    /// is never handed a left with no right to follow it.
    func addSet(exercise: Binding<WorkoutExerciseModel>) {
        guard let userId = interactor.userId else { return }
        let existingSets = exercise.wrappedValue.sets
        // One past the highest index, not one past the count. Deleting a set does not renumber the
        // rest, so after deleting any set but the last, the count no longer reaches the top index
        // and this handed the new set an index another set already held. Warmup sets share the
        // same numbering, which makes it easier still to hit.
        var nextIndex = (existingSets.map(\.index).max() ?? 0) + 1
        for side in exercise.wrappedValue.sidesPerSet {
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
        // A system alert now, which dismisses itself.
        router.showWarmupSetInfoModal { }
    }

    func updateWeightUnit(_ unit: ExerciseWeightUnit, for exercise: Binding<WorkoutExerciseModel>) {
        let templateId: String = exercise.wrappedValue.templateId
        interactor.setWeightUnit(unit, for: templateId)
    }

    func convertAndRoundWeights(to newUnit: ExerciseWeightUnit, for exercise: Binding<WorkoutExerciseModel>) {
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
        interactor.setWeightUnit(newUnit, for: exercise.wrappedValue.templateId)

    }

    /// Shows a prompt asking whether to just change display unit or convert values
    func promptWeightUnitChange(_ newUnit: ExerciseWeightUnit, for exercise: Binding<WorkoutExerciseModel>) {
        let currentUnit = getUnitPreference(for: exercise.wrappedValue).weightUnit
        guard newUnit != currentUnit else { return }

        router.showConfirmationDialog(
            title: String(localized: "Change Weight Unit"),
            subtitle: String(localized: "How would you like to change the unit for '\(exercise.wrappedValue.name)'?"),
            buttons: {
                AnyView(
                    VStack(spacing: Spacing.s) {
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

        router.showConfirmationDialog(
            title: String(localized: "Change Distance Unit"),
            subtitle: String(localized: "How would you like to change the unit for '\(exercise.wrappedValue.name)'?"),
            buttons: {
                AnyView(
                    VStack(spacing: Spacing.s) {
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
