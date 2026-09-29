//
//  SetDetailRow.swift
//  DialedIn
//
//  Created by Andrew Coyle on 19/10/2025.
//

import SwiftUI

struct SetDetailRow: View {
    let set: WorkoutSetModel
    let index: Int
    let trackingMode: TrackingMode
    /// Weights are stored in kg and shown in the unit the user logs this exercise in. The row used
    /// to print kg whatever that was.
    var weightUnit: ExerciseWeightUnit = .kilograms
    /// Distances are stored in metres and shown in the exercise's unit. The row used to print
    /// metres whatever that was.
    var distanceUnit: ExerciseDistanceUnit = .meters

    var weightText: String? {
        self.set.weightKg.map { Format.weight(kg: $0, unit: weightUnit) }
    }

    /// What the set was, in the exercise's own terms: "80 kg × 8 reps", "12 reps", "0:45",
    /// "400 m in 1:32". Nil when the set holds nothing its tracking mode shows.
    var valueText: String? {
        switch trackingMode {
        case .weightReps:
            guard let weightText, let reps = self.set.reps else { return nil }
            return "\(weightText) × \(Format.reps(reps))"
        case .repsOnly:
            return self.set.reps.map { Format.reps($0) }
        case .timeOnly:
            return self.set.durationSec.map { Format.duration(TimeInterval($0)) }
        case .distanceTime:
            let distance = self.set.distanceMeters.map { Format.distance(meters: $0, exerciseUnit: distanceUnit) }
            let duration = self.set.durationSec.map { Format.duration(TimeInterval($0)) }
            switch (distance, duration) {
            case let (distance?, duration?): return String(localized: "\(distance) in \(duration)")
            case let (distance?, nil): return distance
            case let (nil, duration?): return duration
            case (nil, nil): return nil
            }
        }
    }

    /// A left/right pair shares its number and is told apart by the marker, so three sets a side
    /// read 1L, 1R, 2L, 2R rather than 1 through 4.
    private var label: String {
        String(localized: "Set \(String(describing: index))\(set.side?.initial ?? "")")
    }

    var body: some View {
        HStack(spacing: Spacing.m) {
            Text(label)
                .foregroundStyle(.secondary)

            if let valueText {
                Text(valueText)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)

            if let rpe = set.rpe {
                Text("RPE \(rpe.formatted(.number.precision(.fractionLength(0...1))))")
                    .font(.label)
                    .foregroundStyle(.secondary)
            }

            if set.isWarmup {
                Chip("Warm-up", systemImage: Symbol.warmup, tint: .warmup)
            }
        }
        .font(.rowDetail)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        SetDetailRow(
            set: WorkoutSetModel.mock,
            index: 1,
            trackingMode: TrackingMode.weightReps
        )
    }
}
