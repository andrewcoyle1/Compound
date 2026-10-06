//
//  ActiveWorkout+Focus.swift
//  Compound
//
//  Where the card goes: the blocks a workout is worked in, the order of sets inside a superset,
//  and what the card does after a set is logged and when a rest ends. One rule for all of it, so
//  the log button, the card and auto-advance cannot disagree about what comes next.
//

import Foundation

extension ActiveWorkout {

    // MARK: - Blocks

    /// The workout as it is worked: an exercise on its own is a block of one, and a superset is
    /// one block holding its members, placed where its first member is. Exercise ids, in workout
    /// order.
    static func blocks(_ exercises: [WorkoutExerciseModel]) -> [[String]] {
        var blocks: [[String]] = []
        var blockIndexByGroup: [String: Int] = [:]
        for exercise in exercises {
            if let group = exercise.supersetGroupId, let index = blockIndexByGroup[group] {
                blocks[index].append(exercise.id)
                continue
            }
            if let group = exercise.supersetGroupId { blockIndexByGroup[group] = blocks.count }
            blocks.append([exercise.id])
        }
        return blocks
    }

    /// The round a set belongs to in a superset: its set number, so A1 and B1 are one round and a
    /// left/right pair is one entry in it. Warm-ups come before the first round.
    static func round(of set: WorkoutSetModel, in exercise: WorkoutExerciseModel) -> Int {
        set.isWarmup ? 0 : exercise.workingSetNumber(for: set)
    }

    /// The set a block is up to, walking its members in rounds (A1, B1, A2, B2…) and skipping
    /// members with nothing left: the earliest round any member still has open, and within it the
    /// first member from `startMember` on, wrapping. Each member offers its own current set.
    static func nextSet(
        inBlock block: [String],
        of exercises: [WorkoutExerciseModel],
        from startMember: Int = 0
    ) -> (exerciseId: String, setId: String)? {
        let members = block.compactMap { id in exercises.first { $0.id == id } }
        let open = members.compactMap { member in
            currentSet(in: member).map { (exercise: member, set: $0, round: round(of: $0, in: member)) }
        }
        guard let earliest = open.map(\.round).min(), !members.isEmpty else { return nil }
        let order = members.indices.map { (startMember + $0) % members.count }
        for index in order {
            if let entry = open.first(where: { $0.exercise.id == members[index].id }), entry.round == earliest {
                return (entry.exercise.id, entry.set.id)
            }
        }
        return nil
    }

    private static func blockIndex(of exerciseId: String?, in blocks: [[String]]) -> Int? {
        blocks.firstIndex { $0.contains(exerciseId ?? "") }
    }

    /// The first exercise to open in the next block with sets left after `blockIndex`, wrapping
    /// round to any put off earlier.
    static func nextBlockExercise(after blockIndex: Int?, in blocks: [[String]], of exercises: [WorkoutExerciseModel]) -> String? {
        let start = blockIndex.map { $0 + 1 } ?? 0
        for offset in blocks.indices {
            let candidate = (start + offset) % blocks.count
            if candidate == blockIndex { continue }
            if let next = nextSet(inBlock: blocks[candidate], of: exercises) { return next.exerciseId }
        }
        return nil
    }

    // MARK: - After a set is logged

    /// Where the card goes once `setId` is logged (`exercises` already holding it), or `nil` to
    /// stay where it is.
    ///
    /// - Inside a superset with sets left, to the member next in the round, as
    ///   `supersetAutoScroll` asks.
    /// - The exercise or superset finished with a rest to follow: stay, so the set just done can
    ///   be reviewed or another added. `focusWhenRestEnds` moves on afterwards.
    /// - Finished with no rest: on to the next block with sets left, as `exerciseAutoNext` asks.
    static func focus(
        afterLogging setId: String,
        in exercises: [WorkoutExerciseModel],
        settings: WorkoutSettings,
        restFollows: Bool
    ) -> String? {
        guard let exercise = exercises.first(where: { $0.sets.contains { $0.id == setId } }) else { return nil }
        let blocks = blocks(exercises)
        guard let blockIndex = blockIndex(of: exercise.id, in: blocks) else { return nil }
        let block = blocks[blockIndex]

        if nextSet(inBlock: block, of: exercises) != nil {
            guard block.count > 1, settings.supersetAutoScroll,
                  let member = block.firstIndex(of: exercise.id),
                  let next = nextSet(inBlock: block, of: exercises, from: member + 1),
                  next.exerciseId != exercise.id else { return nil }
            return next.exerciseId
        }

        guard !restFollows, settings.exerciseAutoNext else { return nil }
        return nextBlockExercise(after: blockIndex, in: blocks, of: exercises)
    }

    /// Where the card goes when a rest ends, or is skipped, with the card on `current`: on from
    /// a finished exercise to whatever the log button's Next offers, when `exerciseAutoNext` is on.
    /// `nil` while `current` still has sets to log.
    static func focusWhenRestEnds(current: String?, exercises: [WorkoutExerciseModel], settings: WorkoutSettings) -> String? {
        guard settings.exerciseAutoNext,
              let exercise = exercises.first(where: { $0.id == current }),
              currentSet(in: exercise) == nil,
              case let .next(exerciseId)? = primaryAction(exercises: exercises, currentExerciseId: current)
        else { return nil }
        return exerciseId
    }
}
