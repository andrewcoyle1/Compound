//
//  ActiveWorkout+Pieces.swift
//  Compound
//
//  The set plan on the card (Workout Settings › Set Plan): what comes straight after the set the
//  button logs, when it is a drop or mini-set of that set, and the plan an exercise opens with,
//  in a sentence. Pure, so each rule is tested without a screen.
//

import Foundation

extension ActiveWorkout {

    /// The piece after a set, for the log button's second line.
    struct PieceHint: Equatable {
        /// "drop 1 · 80 kg, no rest", "mini-set 2 · 160 kg × 5, 15 s breath".
        let text: String
        /// "drop 1, 80 kilograms, no rest": the same for VoiceOver.
        let spokenText: String
    }

    /// The next row still to log after `setId`, when it is a drop or mini-set: a drop follows with
    /// no rest, a mini-set after its kind's short breath (`WorkoutSettings.intraSetRest(for:)`).
    /// `nil` when the next row is a set of its own, or there is none.
    static func nextPiece(
        after setId: String,
        in exercise: WorkoutExerciseModel,
        settings: WorkoutSettings,
        unit: ExerciseWeightUnit,
        distanceUnit: ExerciseDistanceUnit = .meters
    ) -> PieceHint? {
        guard let position = exercise.sets.firstIndex(where: { $0.id == setId }),
              let next = exercise.sets[(position + 1)...].first(where: { $0.completedAt == nil }),
              let subKind = next.subSetKind else { return nil }
        let ordinal = subSetOrdinal(of: next, in: exercise.sets)
        let name = subKind == .drop ? String(localized: "drop \(ordinal)") : String(localized: "mini-set \(ordinal)")

        // A plain mini-set rests as its parent's kind does, as `RestDurationRules` reads it.
        let parentKind = exercise.sets.first { $0.id == next.parentSetId }?.kind ?? .standard
        let seconds = settings.intraSetRest(for: next.kind == .standard ? parentKind : next.kind) ?? 0
        let rest = seconds > 0 ? String(localized: "\(seconds) s breath") : String(localized: "no rest")

        let mode = exercise.trackingMode
        let shown = figures(of: next, trackingMode: mode, unit: unit, distanceUnit: distanceUnit)
            ?? weightOnly(next, trackingMode: mode).map { Format.weight(kg: $0, unit: unit) }
        let spoken = spokenFigures(of: next, trackingMode: mode, unit: unit, distanceUnit: distanceUnit)
        return PieceHint(
            text: [shown.map { "\(name) · \($0)" } ?? name, rest].joined(separator: ", "),
            spokenText: [name, spoken, rest].compactMap { $0 }.joined(separator: ", ")
        )
    }

    /// The plan `exercise` opens with, for the progression note: "Set 3 is a drop set from your
    /// plan: 100 × 8, then 80 and 64 to failure, no rest between. Set 4 is AMRAP, target 8+."
    /// Only for drops and mini-sets under a set, and AMRAP targets, as the session was created
    /// with them, so `nil` once a working set is logged or when there is no plan to tell.
    static func planSummary(for exercise: WorkoutExerciseModel, unit: ExerciseWeightUnit) -> String? {
        guard !exercise.sets.contains(where: { !$0.isWarmup && $0.completedAt != nil }) else { return nil }
        // A left/right pair is one set: its left row speaks for it.
        let sentences = exercise.sets.filter { !$0.isWarmup && !$0.isSubSet && $0.side != .right }.compactMap { set -> String? in
            let number = exercise.workingSetNumber(for: set)
            let pieces = subSets(of: set.id, in: exercise.sets).filter { $0.side == set.side }
            let first = planFigures(set, unit: unit, trackingMode: exercise.trackingMode)
            if set.kind == .amrap, let target = set.targetReps {
                return String(localized: "Set \(number) is AMRAP, target \(target)+.")
            }
            let drops = pieces.filter { $0.subSetKind == .drop }
            if !drops.isEmpty {
                let weights = drops
                    .map { weightOnly($0, trackingMode: exercise.trackingMode).map { plainWeight($0, unit: unit) } ?? Format.placeholder }
                    .formatted(.list(type: .and))
                if let reps = drops.first?.reps {
                    return String(localized: "Set \(number) is a drop set from your plan: \(first), then \(weights) × \(reps), no rest between.")
                }
                return String(localized: "Set \(number) is a drop set from your plan: \(first), then \(weights) to failure, no rest between.")
            }
            let minis = pieces.count(where: { $0.subSetKind == .mini })
            if minis > 0 {
                let count = String(localized: "\(minis) mini-sets")
                return String(localized: "Set \(number) is \(set.kind.displayName) from your plan: \(first), then \(count), a short breath between.")
            }
            return nil
        }
        return sentences.isEmpty ? nil : sentences.joined(separator: " ")
    }

    /// "100 × 8", "100", "8 reps": a piece's figures as the plan reads them, the unit left to the
    /// rows around it.
    private static func planFigures(_ set: WorkoutSetModel, unit: ExerciseWeightUnit, trackingMode: TrackingMode) -> String {
        switch (weightOnly(set, trackingMode: trackingMode).map { plainWeight($0, unit: unit) }, set.reps) {
        case let (weight?, reps?): "\(weight) × \(reps)"
        case let (weight?, nil): weight
        case let (nil, reps?): Format.reps(reps)
        case (nil, nil): Format.placeholder
        }
    }

    /// A row's weight in kilograms, when it has one worth showing.
    private static func weightOnly(_ set: WorkoutSetModel, trackingMode: TrackingMode) -> Double? {
        guard trackingMode == .weightReps, let weightKg = set.weightKg, weightKg != 0 else { return nil }
        return weightKg
    }

    /// "80", "176.4": a weight in the exercise's unit with no unit after it.
    private static func plainWeight(_ kilograms: Double, unit: ExerciseWeightUnit) -> String {
        UnitConversion.convertWeight(kilograms, to: unit).formatted(.number.precision(.fractionLength(0...1)))
    }
}

// MARK: - On the screen

extension WorkoutTrackerPresenter {

    /// The log button's second line: the drop or mini-set that follows the set it logs. `nil`
    /// with the set plan off, and whenever the button does anything but log a set.
    var primarySlotNextPiece: ActiveWorkout.PieceHint? {
        let settings = interactor.workoutSettings
        guard settings.plansSets, case let .log(exerciseId, setId)? = primarySlot,
              let exercise = workoutSession.exercises.first(where: { $0.id == exerciseId }) else { return nil }
        let units = units(for: exercise)
        return ActiveWorkout.nextPiece(after: setId, in: exercise, settings: settings, unit: units.weightUnit, distanceUnit: units.distanceUnit)
    }
}
