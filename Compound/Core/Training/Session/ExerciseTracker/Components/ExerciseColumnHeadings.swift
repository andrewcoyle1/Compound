//
//  ExerciseColumnHeadings.swift
//  Compound
//
//  The column headings over one exercise's rows, with its unit menus.
//

import SwiftUI

struct ExerciseColumnHeadings: View {

    let presenter: ExerciseTrackerPresenter
    let exercise: Binding<WorkoutExerciseModel>
    /// Names a superset member's own headings ("B2"); `nil` reads "Set".
    var setLabel: String?

    @AppStorage(ExerciseTrackerPresenter.showAutoRangesKey) private var showAutoRanges = false

    var body: some View {
        let units = presenter.getUnitPreference(for: exercise.wrappedValue)
        SetTableHeadings(
            setLabel: setLabel,
            fields: SetKeyboardField.fields(for: exercise.wrappedValue.trackingMode),
            showsAuto: $showAutoRanges
        ) { field in
            switch field {
            case .weight: weightUnitMenu(units.weightUnit)
            case .reps: Text("Reps")
            case .distance: distanceUnitMenu(units.distanceUnit)
            case .duration: Text("Time")
            }
        }
    }

    private func weightUnitMenu(_ selected: ExerciseWeightUnit) -> some View {
        UnitMenu(units: ExerciseWeightUnit.allCases, selected: selected, name: \.displayName) {
            presenter.promptWeightUnitChange($0, for: exercise)
        } label: {
            Text(presenter.weightColumnTitle(for: exercise.wrappedValue, unit: selected))
                .accessibilityLabel(presenter.weightColumnLabel(for: exercise.wrappedValue, unit: selected))
        }
    }

    private func distanceUnitMenu(_ selected: ExerciseDistanceUnit) -> some View {
        UnitMenu(units: ExerciseDistanceUnit.allCases, selected: selected, name: \.displayName) {
            presenter.promptDistanceUnitChange($0, for: exercise)
        } label: {
            Text(selected.abbreviation.capitalized)
                .accessibilityLabel(String(localized: "Distance unit, \(selected.displayName)"))
        }
    }
}
