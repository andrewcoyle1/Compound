//
//  ActiveWorkout+Correction.swift
//  Compound
//
//  The correction row under the set just logged: which set it follows, what it says, and how its
//  reps-in-reserve chips map onto the RPE the set stores.
//

import Foundation

extension ActiveWorkout {

    // MARK: - Which set

    /// The set the correction row sits under, or `nil` for none: the set logged last anywhere in
    /// the workout, when it is a working set of `exercise`. It holds until the next set is logged
    /// or the card shows another exercise, whether or not a rest is running. Warm-ups get no row:
    /// they fold away once logged, and effort on a warm-up means nothing.
    static func correctionTarget(in exercise: WorkoutExerciseModel, latestLogged: WorkoutSetModel?) -> String? {
        guard let latestLogged, latestLogged.completedAt != nil, !latestLogged.isWarmup,
              exercise.sets.contains(where: { $0.id == latestLogged.id }) else { return nil }
        return latestLogged.id
    }

    // MARK: - Reps in reserve

    /// The chips, in reps in reserve. The last one reads "4+".
    static let rirChips = [0, 1, 2, 3, 4]

    /// The RPE a chip stores: 0 → 10, 1 → 9, … and 4+ → 6.
    static func rirChip(_ rir: Int) -> Double {
        EffortScale.rpe(fromRIR: min(max(rir, 0), 4))
    }

    /// The chip that shows `rpe` as selected, or `nil` for none. A half step chosen on the keypad
    /// (RPE 8.5) falls between two chips and selects neither; anything easier than RPE 6 is 4+.
    static func rirChip(forRPE rpe: Double?) -> Int? {
        guard let rpe else { return nil }
        let rir = EffortScale.rir(fromRPE: rpe)
        if rir >= 4 { return 4 }
        return rir >= 0 && rir == rir.rounded() ? Int(rir) : nil
    }

    // MARK: - What it says

    /// "2", "1L": the set's number among the working sets, and its side.
    static func setNumberLabel(for set: WorkoutSetModel, in exercise: WorkoutExerciseModel) -> String {
        "\(exercise.workingSetNumber(for: set))\(set.side?.initial ?? "")"
    }

    /// "Set 2 · 100 kg × 8", as the row shows it.
    static func correctionTitle(
        for set: WorkoutSetModel,
        in exercise: WorkoutExerciseModel,
        unit: ExerciseWeightUnit,
        distanceUnit: ExerciseDistanceUnit
    ) -> String {
        let name = String(localized: "Set \(setNumberLabel(for: set, in: exercise))")
        guard let figures = figures(of: set, trackingMode: exercise.trackingMode, unit: unit, distanceUnit: distanceUnit) else {
            return name
        }
        return "\(name) · \(figures)"
    }

    /// "Set 2 logged, 100 kilograms, 8 reps": the row as VoiceOver reads it, units in words.
    static func correctionSpokenLabel(
        for set: WorkoutSetModel,
        in exercise: WorkoutExerciseModel,
        unit: ExerciseWeightUnit,
        distanceUnit: ExerciseDistanceUnit,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        var parts: [String] = []
        if exercise.trackingMode == .weightReps, let weightKg = set.weightKg, weightKg > 0 {
            parts.append(spokenWeight(kg: weightKg, unit: unit, locale: locale))
        }
        switch exercise.trackingMode {
        case .weightReps, .repsOnly:
            if let reps = set.reps { parts.append(Format.reps(reps, locale: locale)) }
        case .timeOnly, .distanceTime:
            if let figures = figures(of: set, trackingMode: exercise.trackingMode, unit: unit, distanceUnit: distanceUnit) {
                parts.append(figures)
            }
        }
        return String(localized: "Set \(setNumberLabel(for: set, in: exercise)) logged, \(parts.joined(separator: ", "))")
    }

    /// "102.5 kilograms", "225 pounds": a weight with its unit in words, for VoiceOver, which
    /// reads "kg" letter by letter in some languages.
    static func spokenWeight(kg kilograms: Double, unit: ExerciseWeightUnit, locale: Locale = .autoupdatingCurrent) -> String {
        let value = (UnitConversion.convertWeight(kilograms, to: unit) * 100).rounded() / 100
        return Measurement(value: value, unit: unit == .pounds ? UnitMass.pounds : UnitMass.kilograms)
            .formatted(.measurement(width: .wide, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...2))).locale(locale))
    }
}
