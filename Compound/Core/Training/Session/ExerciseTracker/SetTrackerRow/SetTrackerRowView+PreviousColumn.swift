//
//  SetTrackerRowView+PreviousColumn.swift
//  Compound
//
//  The row's Last / Auto column: last session's figures or smart progression's suggestion, a tap
//  on either filling the set.
//

import SwiftUI

extension SetTrackerRowView {

    func previousValues(units: ExerciseUnitPreference) -> some View {
        Group {
            if delegate.showAutoRanges {
                autoTargetContent(units: units)
            } else {
                lastSessionContent(units: units)
            }
        }
        .setColumn(width: SetTable.previousColumnWidth, stretches: isStacked, alignment: .leading)
    }

    @ViewBuilder
    private func autoTargetContent(units: ExerciseUnitPreference) -> some View {
        let exercise = delegate.exercise.wrappedValue
        let set = delegate.set.wrappedValue
        // A drop or mini-set has no target of its own; its set's would read as the drop's.
        if set.isWarmup || set.isSubSet {
            emptyTargetLabel
        } else {
            // The same number the row is labelled with, so a pair shares one target: a target
            // describes a set, and a left and a right are the one set.
            let workingIndex = exercise.workingSetNumber(for: set)
            let target = exercise.setTargets.first { $0.setNumber == workingIndex }
            let suggestion = delegate.progressionSuggestion
            if let suggestion, let label = suggestion.label(
                trackingMode: exercise.trackingMode,
                weightUnit: units.weightUnit,
                distanceUnit: units.distanceUnit
            ) {
                SetColumnValue(text: label, onFill: { presenter.onFillFromSuggestion(suggestion, set: delegate.set) }, isLogged: set.completedAt != nil)
            } else if let target {
                autoRangeLabel(target: target)
            } else {
                emptyTargetLabel
            }
        }
    }

    private var emptyTargetLabel: some View {
        SetColumnValue(text: Format.placeholder)
    }

    private func autoRangeLabel(target: SetTarget) -> some View {
        let label = switch (target.minReps, target.maxReps) {
        case (let min?, let max?): Format.repRange(min, max)
        case (let min?, nil): "\(min)+"
        default: Format.placeholder
        }
        return SetColumnValue(text: label)
    }

    /// Last session's figures, with the reps left in reserve under them when they were logged.
    @ViewBuilder
    private func lastSessionContent(units: ExerciseUnitPreference) -> some View {
        let trackingMode = delegate.exercise.wrappedValue.trackingMode
        if let prev = delegate.lastSet, let text = ActiveWorkout.lastColumnText(
            of: prev,
            trackingMode: trackingMode,
            unit: units.weightUnit,
            distanceUnit: units.distanceUnit,
            showsBodyweight: showsBodyweightLoad
        ) {
            let isDistance = trackingMode == .distanceTime
            let showsRIR = trackingMode == .weightReps || trackingMode == .repsOnly
            SetColumnValue(
                text: text,
                font: isDistance ? .caption2 : .label,
                lineLimit: isDistance ? 2 : nil,
                footnote: showsRIR ? prev.rpe.map { String(localized: "RIR \(WeightStepper.format(EffortScale.rir(fromRPE: $0)))") } : nil,
                onFill: { presenter.onFillFromPrevious(prev, trackingMode: trackingMode, set: delegate.set) },
                isLogged: delegate.set.wrappedValue.completedAt != nil
            )
        } else {
            emptyTargetLabel
        }
    }
}
