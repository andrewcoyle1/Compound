//
//  StravaStrengthFile.swift
//  Compound
//
//  A finished workout in Strava's JSON strength format, the file `POST /uploads` takes with
//  `data_type=json`. Strava turns its sets into the activity's exercise list and muscle map.
//  https://developers.strava.com/docs/uploads/
//

import Foundation

struct StravaStrengthFile: Encodable, Equatable {
    let version = "1.0"
    let startTime: String
    let utcOffset: Int
    let elapsedTime: Int
    let activeTime: Int?
    let creator = Creator(name: "Compound")
    let sets: [StravaStrengthSet]

    struct Creator: Encodable, Equatable {
        let name: String
    }

    enum CodingKeys: String, CodingKey {
        case version
        case startTime = "start_time"
        case utcOffset = "utc_offset"
        case elapsedTime = "elapsed_time"
        case activeTime = "active_time"
        case creator, sets
    }

    /// `nil` for a workout with nothing Strava can take: unfinished, or no completed working set
    /// it can place. Strava refuses a file without a set.
    init?(session: WorkoutSessionModel, library: [ExerciseModel], timeZone: TimeZone = .current) {
        guard let endedAt = session.endedAt else { return nil }
        let sets = session.exercises.flatMap { exercise -> [StravaStrengthSet] in
            guard let type = StravaExerciseType.forExercise(templateId: exercise.templateId, library: library) else { return [] }
            return Self.uploadedRows(exercise.sets).map { row in
                StravaStrengthSet(
                    exerciseType: type,
                    repetitions: row.reps,
                    weight: row.weightKg.flatMap { $0 > 0 ? $0 : nil },
                    duration: row.durationSec
                )
            }
        }
        guard !sets.isEmpty else { return nil }

        let formatter = ISO8601DateFormatter()
        startTime = formatter.string(from: session.dateCreated)
        utcOffset = timeZone.secondsFromGMT(for: session.dateCreated)
        elapsedTime = Int(endedAt.timeIntervalSince(session.dateCreated))
        activeTime = session.activeDuration.map { Int($0) }
        self.sets = sets
    }

    /// Completed working sets, a left/right pair sent once — the rule `pairedSetCount` counts by.
    /// Strava has no sides, and six rows for three sets of a single-arm row would double them on
    /// the map. Warm-ups are left out for the same reason.
    static func uploadedRows(_ rows: [WorkoutSetModel]) -> [WorkoutSetModel] {
        let done = rows.filter { !$0.isWarmup && $0.completedAt != nil }
        return done.enumerated().compactMap { index, row in
            let foldsIntoPrevious = row.side == .right && index > 0 && done[index - 1].side == .left
            return foldsIntoPrevious ? nil : row
        }
    }
}

extension StravaUpload {

    /// The activity's description: the session's notes, then a line per exercise listing the sets
    /// that were uploaded, e.g. "Barbell Bench Press: 100 kg × 8, 100 kg × 8, 95 kg × 7". `nil`
    /// when there is neither.
    static func description(
        for session: WorkoutSessionModel,
        weightUnit: WeightUnitPreference,
        distanceUnit: DistanceUnitPreference
    ) -> String? {
        let lines = session.exercises.compactMap { exercise -> String? in
            let sets = StravaStrengthFile.uploadedRows(exercise.sets).compactMap {
                summary(of: $0, weightUnit: weightUnit, distanceUnit: distanceUnit)
            }
            return sets.isEmpty ? nil : "\(exercise.name): \(sets.joined(separator: ", "))"
        }
        let parts = [session.notes, lines.isEmpty ? nil : lines.joined(separator: "\n")]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }

    private static func summary(of set: WorkoutSetModel, weightUnit: WeightUnitPreference, distanceUnit: DistanceUnitPreference) -> String? {
        let weight = set.weightKg.flatMap { $0 > 0 ? Format.weight(kg: $0, unit: weightUnit) : nil }
        switch (weight, set.reps, set.durationSec, set.distanceMeters) {
        case let (weight?, reps?, _, _): return "\(weight) × \(reps)"
        case let (nil, reps?, _, _): return Format.reps(reps)
        case let (_, nil, _, meters?) where meters > 0: return Format.distance(meters: meters, unit: distanceUnit)
        case let (_, nil, seconds?, _): return Format.duration(TimeInterval(seconds))
        default: return weight
        }
    }
}

/// One set in the file.
struct StravaStrengthSet: Encodable, Equatable {
    let exerciseType: String
    let repetitions: Int?
    /// Kilograms, as the set was logged: per side for an exercise logged per side.
    let weight: Double?
    let duration: Int?

    enum CodingKeys: String, CodingKey {
        case exerciseType = "exercise_type"
        case repetitions, weight, duration
    }
}
