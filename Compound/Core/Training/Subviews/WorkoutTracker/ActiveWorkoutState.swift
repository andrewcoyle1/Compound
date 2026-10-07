//
//  ActiveWorkoutState.swift
//  Compound
//
//  What the active-workout screen works out from the session: which set is next, how far through
//  the workout is, why smart progression changed the numbers, where the rest timer sits and what
//  the log button says. Pure, so each rule is tested without a screen.
//

import Foundation

/// How a set row is drawn.
enum SetRowState: Equatable {
    case done
    /// The next set to log in its exercise: highlighted, its fields outlined.
    case current
    case upcoming
}

/// Where the inline rest timer sits in the current exercise's table.
enum RestAnchor: Equatable {
    /// Under the working set the rest follows.
    case below(setId: String)
    /// Above the first row: the rest followed a warm-up, which is hidden once logged, or another
    /// exercise's set, as it does after a superset partner or the last set of the exercise before.
    case top
}

/// What the button at the foot of the screen does.
enum ActiveWorkoutAction: Equatable {
    case logSet(exerciseId: String, setId: String)
    /// The current exercise is done; open the next one with anything left to log.
    case next(exerciseId: String)
    case finish
}

enum ActiveWorkout {

    // MARK: - Rows

    /// The set the user is on: the first one not yet logged, warm-ups included. A left/right pair
    /// is two rows, and the left is current first.
    static func currentSet(in exercise: WorkoutExerciseModel) -> WorkoutSetModel? {
        exercise.sets.first { $0.completedAt == nil }
    }

    static func rowState(of set: WorkoutSetModel, in exercise: WorkoutExerciseModel) -> SetRowState {
        if set.completedAt != nil { return .done }
        return currentSet(in: exercise)?.id == set.id ? .current : .upcoming
    }

    // MARK: - Header

    struct Progress: Equatable {
        let doneWorkingSets: Int
        let totalWorkingSets: Int
        /// Which block of how many: a superset counts once (`blocks(_:)`), so the count holds
        /// still while its members alternate.
        let exerciseNumber: Int
        let exerciseCount: Int
        /// The current block is a superset: the header reads "Superset 2 of 5".
        var isSuperset = false

        var fraction: Double {
            totalWorkingSets == 0 ? 0 : Double(doneWorkingSets) / Double(totalWorkingSets)
        }
    }

    /// Working sets only: warm-ups are preparation, and counting them made a workout with smart
    /// warm-ups look a third done before the first real set. A pair counts once, when both sides are.
    static func progress(of exercises: [WorkoutExerciseModel], currentIndex: Int) -> Progress {
        let working = exercises.map { $0.sets.filter { !$0.isWarmup } }
        let blocks = blocks(exercises)
        let current = exercises.isEmpty ? nil : exercises[min(max(currentIndex, 0), exercises.count - 1)].id
        let blockIndex = blocks.firstIndex { $0.contains(current ?? "") }
        return Progress(
            doneWorkingSets: working.reduce(0) { $0 + $1.fullyCompletedPairedSetCount },
            totalWorkingSets: working.reduce(0) { $0 + $1.pairedSetCount },
            exerciseNumber: blockIndex.map { $0 + 1 } ?? 0,
            exerciseCount: blocks.count,
            isSuperset: blockIndex.map { blocks[$0].count > 1 } ?? false
        )
    }

    // MARK: - Exercise card

    /// Why today's numbers differ from last time, in a sentence: "+2.5 kg today. You hit 5 reps on
    /// every working set last time." `nil` when smart progression held the numbers or had no
    /// history, when the suggested change came to nothing after rounding, and once the user has
    /// typed other numbers into the first working set: the sentence would no longer be true.
    static func progressionReason(
        suggestion: ProgressionSuggestion?,
        planned: WorkoutExerciseModel? = nil,
        last: WorkoutExerciseModel?,
        unit: ExerciseWeightUnit
    ) -> String? {
        guard let suggestion, let last, !isEdited(planned, from: suggestion) else { return nil }
        // The left of a split pair stands for the set, as `ProgressionPlanner` reads it.
        let lastWorking = last.sets.filter { !$0.isWarmup && $0.completedAt != nil && $0.side != .right }
        guard let lastFirst = lastWorking.first,
              let today = suggestion.sets.first(where: { !$0.isEmpty }) else { return nil }

        switch suggestion.rationale {
        case .progressWeight, .deload:
            guard let now = today.weightKg, let was = lastFirst.weightKg, abs(now - was) > 0.001 else { return nil }
            let change = signedWeight(now - was, unit: unit)
            if suggestion.rationale == .deload {
                return String(localized: "\(change) today. A lighter week to recover.")
            }
            guard let reps = lastWorking.compactMap(\.reps).min() else {
                return String(localized: "\(change) today.")
            }
            return String(localized: "\(change) today. You hit \(Format.reps(reps)) on every working set last time.")
        case .addReps:
            guard let now = today.reps, let was = lastFirst.reps, now > was else { return nil }
            return String(localized: "+\(Format.reps(now - was)) today, at the same weight as last time.")
        case .hold, .noHistory:
            return nil
        }
    }

    /// True once the first working set no longer holds what was suggested for it.
    private static func isEdited(_ planned: WorkoutExerciseModel?, from suggestion: ProgressionSuggestion) -> Bool {
        guard let first = planned?.sets.first(where: { !$0.isWarmup }), let suggested = suggestion.sets.first else { return false }
        if let weight = suggested.weightKg, abs((first.weightKg ?? -1) - weight) > 0.001 { return true }
        if let reps = suggested.reps, first.reps != reps { return true }
        return false
    }

    /// "+2.5 kg", "−5 lb": the change in the exercise's own unit.
    static func signedWeight(_ kilograms: Double, unit: ExerciseWeightUnit) -> String {
        let text = Format.weight(kg: abs(kilograms), unit: unit)
        return kilograms < 0 ? "−\(text)" : "+\(text)"
    }

    // MARK: - Rest

    /// The set logged most recently anywhere in the workout: the one a running rest follows.
    static func latestCompletedSet(in exercises: [WorkoutExerciseModel]) -> WorkoutSetModel? {
        exercises.flatMap(\.sets)
            .filter { $0.completedAt != nil }
            .max { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
    }

    /// Where the rest timer goes in `exercise`'s table, or `nil` to leave it out.
    ///
    /// Under the working set it follows when that set is in this exercise; otherwise at the top,
    /// where it reads as the rest before this exercise's next set. Left out once a set has been
    /// logged since the rest began, as happens with rest timers off for that set: the timer belongs
    /// to the set before.
    static func restAnchor(in exercise: WorkoutExerciseModel, restedSet: WorkoutSetModel?, restStartedAt: Date?) -> RestAnchor? {
        guard let restedSet, let loggedAt = restedSet.completedAt else { return .top }
        if let restStartedAt, loggedAt > restStartedAt { return nil }
        let isHere = exercise.sets.contains { $0.id == restedSet.id }
        return isHere && !restedSet.isWarmup ? .below(setId: restedSet.id) : .top
    }

    // MARK: - Footer

    /// Log the card's next set; once its block has none, move to the next block with sets left,
    /// wrapping round to any skipped earlier; once nothing is left anywhere, finish.
    ///
    /// A superset is worked in rounds (A1, B1, A2, B2…, `nextSet(inBlock:)`). When the round's
    /// next set belongs to a partner rather than the card, the button opens the partner, so it
    /// never logs a set the card does not show.
    static func primaryAction(exercises: [WorkoutExerciseModel], currentExerciseId: String?) -> ActiveWorkoutAction? {
        let blocks = blocks(exercises)
        let blockIndex = blocks.firstIndex { $0.contains(currentExerciseId ?? "") }
        if let blockIndex, let currentExerciseId {
            let block = blocks[blockIndex]
            let member = block.firstIndex(of: currentExerciseId) ?? 0
            if let next = nextSet(inBlock: block, of: exercises, from: member) {
                return next.exerciseId == currentExerciseId
                    ? .logSet(exerciseId: next.exerciseId, setId: next.setId)
                    : .next(exerciseId: next.exerciseId)
            }
        }
        if let next = nextBlockExercise(after: blockIndex, in: blocks, of: exercises) {
            return .next(exerciseId: next)
        }
        return exercises.contains { !$0.sets.isEmpty } ? .finish : nil
    }

    /// "Log set 2 · 115 kg × 5", "Log warm-up · 60 kg × 5", "Log set 1L · 20 kg × 10".
    static func logTitle(
        for set: WorkoutSetModel,
        in exercise: WorkoutExerciseModel,
        unit: ExerciseWeightUnit,
        distanceUnit: ExerciseDistanceUnit
    ) -> String {
        let name = set.isWarmup
            ? String(localized: "Log warm-up")
            : String(localized: "Log set \("\(exercise.workingSetNumber(for: set))\(set.side?.initial ?? "")")")
        guard let figures = figures(of: set, trackingMode: exercise.trackingMode, unit: unit, distanceUnit: distanceUnit) else {
            return name
        }
        return "\(name) · \(figures)"
    }

    /// "115 kg × 5", "12 reps", "1:30", "400 m · 1:30"; `nil` until the set holds its figures, so
    /// a timed set's title reads "Log set 1" until a time is entered or the stopwatch stops.
    static func figures(
        of set: WorkoutSetModel,
        trackingMode: TrackingMode,
        unit: ExerciseWeightUnit,
        distanceUnit: ExerciseDistanceUnit
    ) -> String? {
        switch trackingMode {
        case .weightReps:
            guard let reps = set.reps else { return nil }
            // A negative weight is assistance: "−30 kg × 8" on an assisted pull-up.
            guard let weightKg = set.weightKg, weightKg != 0 else { return Format.reps(reps) }
            return "\(Format.weight(kg: weightKg, unit: unit)) × \(reps)"
        case .repsOnly:
            return set.reps.map { Format.reps($0) }
        case .timeOnly:
            return set.durationSec.map { Format.duration(TimeInterval($0)) }
        case .distanceTime:
            guard let meters = set.distanceMeters, let seconds = set.durationSec else { return nil }
            return "\(Format.distance(meters: meters, exerciseUnit: distanceUnit)) · \(Format.duration(TimeInterval(seconds)))"
        }
    }

    // MARK: - Up next

    /// "2 sets · Top 32.5 kg × 9": a finished exercise, as it went today.
    static func completedSummary(for exercise: WorkoutExerciseModel, unit: ExerciseWeightUnit, distanceUnit: ExerciseDistanceUnit) -> String {
        let logged = exercise.sets.filter { !$0.isWarmup && $0.completedAt != nil }
        var parts = [Format.sets(Double(logged.pairedSetCount))]
        let top = topSet(of: logged, trackingMode: exercise.trackingMode)
        if let top, let figures = figures(of: top, trackingMode: exercise.trackingMode, unit: unit, distanceUnit: distanceUnit) {
            parts.append(String(localized: "Top \(figures)"))
        }
        return parts.joined(separator: " · ")
    }

    /// "3 sets · 8–12 reps · Last 100 kg × 5": the plan, and the heaviest working set last time.
    static func upNextSummary(
        for exercise: WorkoutExerciseModel,
        last: WorkoutExerciseModel?,
        unit: ExerciseWeightUnit,
        distanceUnit: ExerciseDistanceUnit
    ) -> String {
        // Started and left for later, it says how far it got.
        let logged = exercise.loggedSetCount
        var parts = [logged > 0
            ? String(localized: "\(logged) of \(exercise.workingSetCount) sets")
            : Format.sets(Double(exercise.workingSetCount))]
        if let target = exercise.setTargets.first, target.minReps != nil || target.maxReps != nil {
            parts.append(target.repTargetDescription)
        }
        let lastWorking = last?.sets.filter { !$0.isWarmup && $0.completedAt != nil } ?? []
        let top = topSet(of: lastWorking, trackingMode: exercise.trackingMode)
        if let top, let figures = figures(of: top, trackingMode: exercise.trackingMode, unit: unit, distanceUnit: distanceUnit) {
            parts.append(String(localized: "Last \(figures)"))
        }
        return parts.joined(separator: " · ")
    }

    /// The set a summary calls "Top": the heaviest (then the most reps) for weight and reps, the
    /// longest for a timed set, the farthest for a distance. Ties go to the earlier set.
    static func topSet(of sets: [WorkoutSetModel], trackingMode: TrackingMode) -> WorkoutSetModel? {
        switch trackingMode {
        case .weightReps, .repsOnly:
            sets.max { ($0.weightKg ?? 0, $0.reps ?? 0) < ($1.weightKg ?? 0, $1.reps ?? 0) }
        case .timeOnly:
            sets.max { ($0.durationSec ?? 0) < ($1.durationSec ?? 0) }
        case .distanceTime:
            sets.max { ($0.distanceMeters ?? 0) < ($1.distanceMeters ?? 0) }
        }
    }
}
