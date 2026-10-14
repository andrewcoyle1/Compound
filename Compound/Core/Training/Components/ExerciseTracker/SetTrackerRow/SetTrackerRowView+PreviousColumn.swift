//
//  SetTrackerRowView+PreviousColumn.swift
//  Compound
//
//  The row's Last / Auto column: last session's figures or smart progression's suggestion, a tap
//  on either filling the set.
//

import SwiftUI

extension SetTrackerRowView {

    func previousValues(exercise: Binding<WorkoutExerciseModel>, set: Binding<WorkoutSetModel>) -> some View {
        let unitPreference = presenter.getUnitPreference(for: exercise.wrappedValue)
        return Group {
            if delegate.showAutoRanges {
                autoTargetContent(exercise: exercise.wrappedValue, set: set.wrappedValue)
            } else if let prev = delegate.lastSet {
                previousValueContent(trackingMode: exercise.wrappedValue.trackingMode, prev: prev, unitPreference: unitPreference)
            } else {
                emptyTargetLabel
            }
        }
        .setColumn(width: SetTrackerRowView.previousColumnWidth, stretches: isStacked, alignment: .leading)
    }

    @ViewBuilder
    private func autoTargetContent(exercise: WorkoutExerciseModel, set: WorkoutSetModel) -> some View {
        // A drop or mini-set has no target of its own; its set's would read as the drop's.
        if set.isWarmup || set.isSubSet {
            emptyTargetLabel
        } else {
            // The same number the row is labelled with, so a pair shares one target: a target
            // describes a set, and a left and a right are the one set.
            let workingIndex = exercise.workingSetNumber(for: set)
            let target = exercise.setTargets.first { $0.setNumber == workingIndex }
            let unitPreference = presenter.getUnitPreference(for: exercise)
            let suggestion = delegate.progressionSuggestion
            let label = suggestion?.label(
                trackingMode: exercise.trackingMode,
                weightUnit: unitPreference.weightUnit,
                distanceUnit: unitPreference.distanceUnit
            )

            if let suggestion, let label {
                columnText(label)
                    .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
                    .contentShape(.rect)
                    .anyButton {
                        presenter.onFillFromSuggestion(suggestion, set: delegate.set)
                    }
                    .accessibilityHint("Fills this set")
                    .disabled(delegate.set.wrappedValue.completedAt != nil)
            } else if let target {
                autoRangeLabel(target: target)
            } else {
                emptyTargetLabel
            }
        }
    }

    private var emptyTargetLabel: some View {
        columnText(Format.placeholder)
    }

    /// One value in the Prev or Auto column.
    private func columnText(_ text: String, font: Font = .label) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(.secondary)
            .frame(minHeight: cellHeight)
    }

    private func autoRangeLabel(target: SetTarget) -> some View {
        let label: String = {
            switch (target.minReps, target.maxReps) {
            case (let min?, let max?): return Format.repRange(min, max)
            case (let min?, nil):      return "\(min)+"
            default:                   return Format.placeholder
            }
        }()
        return columnText(label)
    }

    @ViewBuilder
    func previousValueContent(
        trackingMode: TrackingMode,
        prev: WorkoutSetModel,
        unitPreference: (weightUnit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit)
    ) -> some View {
        switch trackingMode {
        case .weightReps:
            // A set with no weight, as on a bodyweight lift, reads "8 reps" rather than nothing, or
            // "BW × 8" while the bodyweight contribution is shown.
            if prev.reps != nil,
               let figures = ActiveWorkout.figures(
                   of: prev,
                   trackingMode: .weightReps,
                   unit: unitPreference.weightUnit,
                   distanceUnit: unitPreference.distanceUnit,
                   showsBodyweight: showsBodyweightLoad
               ) {
                fillFromPrevious(withEffort(columnText(figures), rpe: prev.rpe), prev: prev, trackingMode: trackingMode)
            } else {
                emptyTargetLabel
            }
        case .repsOnly:
            if let reps = prev.reps {
                fillFromPrevious(withEffort(columnText(String(reps)), rpe: prev.rpe), prev: prev, trackingMode: trackingMode)
            } else {
                emptyTargetLabel
            }
        case .timeOnly:
            if let duration = prev.durationSec {
                fillFromPrevious(columnText(Format.duration(TimeInterval(duration))), prev: prev, trackingMode: trackingMode)
            } else {
                emptyTargetLabel
            }
        case .distanceTime:
            if let distance = prev.distanceMeters, let duration = prev.durationSec {
                let displayDistance = Format.distance(meters: distance, exerciseUnit: unitPreference.distanceUnit)
                fillFromPrevious(
                    columnText("\(displayDistance) \(Format.duration(TimeInterval(duration)))", font: .caption2)
                        .lineLimit(2),
                    prev: prev,
                    trackingMode: trackingMode
                )
            } else {
                emptyTargetLabel
            }
        }
    }

    /// Last time's figures with the reps left in reserve under them, when they were logged.
    private func withEffort(_ figures: some View, rpe: Double?) -> some View {
        VStack(spacing: 0) {
            figures
            if let rpe {
                Text("RIR \(WeightStepper.format(EffortScale.rir(fromRPE: rpe)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// A Prev value that fills this set when tapped, for every tracking mode. Not on a logged set,
    /// where a stray tap would overwrite what was recorded.
    private func fillFromPrevious(_ label: some View, prev: WorkoutSetModel, trackingMode: TrackingMode) -> some View {
        label
            .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
            .contentShape(.rect)
            .anyButton {
                presenter.onFillFromPrevious(prev, trackingMode: trackingMode, set: delegate.set)
            }
            .accessibilityHint("Fills this set")
            .disabled(delegate.set.wrappedValue.completedAt != nil)
    }
}
