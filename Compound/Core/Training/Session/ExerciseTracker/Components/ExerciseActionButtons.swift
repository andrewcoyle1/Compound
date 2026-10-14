//
//  ExerciseActionButtons.swift
//  Compound
//
//  The exercise's actions, shared by the card's menu and the editor's bar of chips.
//

import SwiftUI

/// Equipment, Split L/R, Targets, Swap and Superset.
struct ExerciseActionButtons: View {

    /// `nil` when the exercise has no other equipment.
    var onEquipment: (() -> Void)?
    /// Whether the sides are logged apart; `nil` for an exercise that works both at once.
    var isSplit: Binding<Bool>?
    let onTargets: () -> Void
    let onSwap: () -> Void
    /// "Superset…", "Remove Superset" or "Remove Circuit"; `nil` leaves the button out.
    var supersetTitle: String?
    var onSuperset: () -> Void = { }

    var body: some View {
        if let onEquipment {
            Button(action: onEquipment) {
                Label("Equipment", systemImage: Symbol.equipment)
                    .tapTarget()
            }
        }

        if let isSplit {
            // A toggle, so the menu draws a checkmark beside it while the sides are split; a tint
            // is not drawn inside a menu.
            Toggle(isOn: isSplit) {
                Label("Split L/R", systemImage: Symbol.splitSides)
                    .tapTarget()
            }
            .accessibilityLabel("Split left and right")
            .accessibilityHint("Logs each side as its own set")
        }

        Button(action: onTargets) {
            Label("Targets", systemImage: Symbol.goal)
                .tapTarget()
        }

        Button(action: onSwap) {
            Label("Swap", systemImage: Symbol.swap)
                .tapTarget()
        }

        if let supersetTitle {
            Button(action: onSuperset) {
                Label(supersetTitle, systemImage: Symbol.superset)
                    .tapTarget()
            }
        }
    }
}

// Kept out of the struct's body, so Swift still writes the memberwise init this one calls.
extension ExerciseActionButtons {

    init(presenter: ExerciseTrackerPresenter, delegate: ExerciseTrackerDelegate, includesSuperset: Bool = true) {
        let exercise = delegate.exercise
        let current = exercise.wrappedValue
        self.init(
            onEquipment: current.equipmentVariations.isEmpty ? nil : { presenter.onExerciseEquipmentPressed(exercise) },
            isSplit: current.isPerSide ? Binding(
                get: { exercise.wrappedValue.isSplit },
                set: { _ in presenter.onSplitSidesPressed(exercise) }
            ) : nil,
            onTargets: { presenter.onTargetsPressed(exercise) },
            onSwap: { presenter.onSwapPressed(exercise, onSwap: delegate.onSwap) },
            supersetTitle: includesSuperset ? Self.supersetTitle(for: current, in: delegate.allWorkoutExercises) : nil,
            onSuperset: {
                presenter.onSupersetPressed(
                    exercise: exercise,
                    allWorkoutExercises: delegate.allWorkoutExercises,
                    onSetSupersetGroup: delegate.onSetSupersetGroup
                )
            }
        )
    }

    private static func supersetTitle(for exercise: WorkoutExerciseModel, in workout: [WorkoutExerciseModel]) -> String {
        guard let groupId = exercise.supersetGroupId else { return String(localized: "Superset…") }
        let count = workout.filter { $0.supersetGroupId == groupId }.count
        return count > 2 ? String(localized: "Remove Circuit") : String(localized: "Remove Superset")
    }
}
