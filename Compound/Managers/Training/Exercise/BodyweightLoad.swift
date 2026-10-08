//
//  BodyweightLoad.swift
//  Compound
//
//  What a movement's bodyweight contribution (`ExerciseModel.bodyWeightContribution`, a percent)
//  adds to a set: the bodyweight it lifts, the effective load, and how the set reads with it
//  ("BW + 20 kg × 8"). Pure, so each rule is tested without a screen.
//

import Foundation

enum BodyweightLoad {

    /// The bodyweight a movement lifts: 63 % of 84 kg is 52.9 kg. `nil` when no bodyweight is known.
    static func contributionKg(bodyweightKg: Double?, percent: Int) -> Double? {
        guard let bodyweightKg, bodyweightKg > 0 else { return nil }
        return bodyweightKg * Double(min(max(percent, 0), 100)) / 100
    }

    /// The external load plus the bodyweight lifted. Assistance is a negative external load, so it
    /// takes off the bodyweight, never below nothing.
    static func effectiveKg(external: Double?, contribution: Double?) -> Double {
        max(0, (external ?? 0) + (contribution ?? 0))
    }

    /// "BW + 20 kg", "BW − 20 kg" when assisted, "BW" with no external load. Without bodyweight it
    /// is the plain weight, or `nil` when there is none to show.
    static func label(weightKg: Double?, unit: ExerciseWeightUnit, showsBodyweight: Bool) -> String? {
        let weight = weightKg.flatMap { $0 == 0 ? nil : $0 }
        guard showsBodyweight else {
            return weight.flatMap { $0 > 0 ? Format.weight(kg: $0, unit: unit) : nil }
        }
        let bodyweight = String(localized: "BW")
        guard let weight else { return bodyweight }
        return "\(bodyweight) \(weight < 0 ? "−" : "+") \(Format.weight(kg: abs(weight), unit: unit))"
    }

    /// A set's volume at its effective load: the external load as `WorkoutSetModel.volumeKg` counts
    /// it (a weight per side twice), plus the bodyweight once, per rep. With no contribution it is
    /// the set's own volume.
    static func volumeKg(of set: WorkoutSetModel, contributionKg: Double?) -> Double? {
        guard let contributionKg, contributionKg > 0 else { return set.volumeKg }
        guard let reps = set.reps else { return nil }
        let external = (set.weightKg ?? 0) * (set.side == .both ? 2 : 1)
        return effectiveKg(external: external, contribution: contributionKg) * Double(reps)
    }
}

/// One exercise's contribution as the tracker shows it. Made only when the setting is on and the
/// movement lifts some bodyweight.
struct BodyweightContribution: Equatable {
    let percent: Int
    /// Today's bodyweight. `nil` when none is known, which hides the badge but keeps the "BW" labels.
    let bodyweightKg: Double?
    /// The exercise's own unit, which the badge shows the bodyweight in.
    let unit: ExerciseWeightUnit

    var contributionKg: Double? {
        BodyweightLoad.contributionKg(bodyweightKg: bodyweightKg, percent: percent)
    }
}
