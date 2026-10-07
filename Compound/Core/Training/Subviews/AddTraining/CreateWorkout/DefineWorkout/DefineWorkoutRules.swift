//
//  DefineWorkoutRules.swift
//  Compound
//
//  The workout editor's list rules: supersets made, unmade and kept together when the list is
//  reordered, the letter each one shows, and the line under an exercise naming its plan. Pure, so
//  the editor and the mesocycle day that hosts it are tested here rather than through a list.
//

import Foundation

enum DefineWorkoutRules {

    // MARK: - Blocks

    /// The workout as it is worked, in the manner of `ActiveWorkout.blocks`: an exercise on its own
    /// is a block of one, and a superset is one block holding its members, placed where its first
    /// member is. Exercise ids, in list order.
    static func blocks(_ exercises: [WorkoutTemplateExercise]) -> [[String]] {
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

    // MARK: - Grouping

    /// The chosen exercises as one superset under `groupId`, gathered where the first of them is.
    /// Fewer than two chosen changes nothing. A chosen exercise leaves the superset it was in, and a
    /// superset left with one member is dissolved.
    static func grouping(_ ids: Set<String>, in exercises: [WorkoutTemplateExercise], groupId: String) -> [WorkoutTemplateExercise] {
        guard exercises.filter({ ids.contains($0.id) }).count >= 2 else { return exercises }
        var result = exercises
        for index in result.indices where ids.contains(result[index].id) {
            result[index].supersetGroupId = groupId
        }
        return gathered(dissolvingLoneGroups(result))
    }

    /// The exercise out of its superset. A superset left with one member is dissolved.
    static func removingFromSuperset(_ id: String, in exercises: [WorkoutTemplateExercise]) -> [WorkoutTemplateExercise] {
        var result = exercises
        guard let index = result.firstIndex(where: { $0.id == id }) else { return exercises }
        result[index].supersetGroupId = nil
        return dissolvingLoneGroups(result)
    }

    /// A superset of one is not a superset: its last member goes back to being on its own. Used
    /// after any removal.
    static func dissolvingLoneGroups(_ exercises: [WorkoutTemplateExercise]) -> [WorkoutTemplateExercise] {
        let counts = Dictionary(exercises.compactMap(\.supersetGroupId).map { ($0, 1) }, uniquingKeysWith: +)
        return exercises.map { exercise in
            guard let group = exercise.supersetGroupId, counts[group, default: 0] < 2 else { return exercise }
            var single = exercise
            single.supersetGroupId = nil
            return single
        }
    }

    /// Each superset's members side by side, where its first member is.
    private static func gathered(_ exercises: [WorkoutTemplateExercise]) -> [WorkoutTemplateExercise] {
        let byId = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return blocks(exercises).flatMap { $0.compactMap { byId[$0] } }
    }

    // MARK: - Letters

    /// "A", "B"… per superset, by first appearance in the list. Exercises on their own have none.
    static func supersetLetters(_ exercises: [WorkoutTemplateExercise]) -> [String: String] {
        var letters: [String: String] = [:]
        for block in blocks(exercises) where block.count > 1 {
            guard let group = exercises.first(where: { $0.id == block[0] })?.supersetGroupId else { continue }
            letters[group] = letter(letters.count)
        }
        return letters
    }

    /// A to Z, then numbers: no workout is expected to hold 27 supersets.
    private static func letter(_ index: Int) -> String {
        guard index < 26, let scalar = UnicodeScalar(65 + index) else { return "\(index + 1)" }
        return String(Character(scalar))
    }

    // MARK: - Reordering

    /// `move(fromOffsets:toOffset:)` that keeps each superset together. A member dragged within its
    /// own superset changes places inside it; dragged anywhere else, it takes its whole superset
    /// with it. Nothing lands between the members of another superset: a drop there goes before it
    /// when moving up and after it when moving down.
    static func moving(_ exercises: [WorkoutTemplateExercise], from source: IndexSet, to destination: Int) -> [WorkoutTemplateExercise] {
        var result = exercises
        if source.count == 1, let index = source.first, let run = run(of: exercises[index].supersetGroupId, in: exercises),
           (run.lowerBound...run.upperBound + 1).contains(destination) {
            result.move(fromOffsets: source, toOffset: destination)
            return result
        }

        let movingGroups = Set(source.compactMap { exercises[$0].supersetGroupId })
        let moving = IndexSet(exercises.indices.filter { index in
            source.contains(index) || exercises[index].supersetGroupId.map(movingGroups.contains) == true
        })
        var target = destination
        if target > 0, target < exercises.count,
           let group = exercises[target].supersetGroupId, !movingGroups.contains(group),
           exercises[target - 1].supersetGroupId == group,
           let run = run(of: group, in: exercises) {
            target = (moving.first ?? 0) < target ? run.upperBound + 1 : run.lowerBound
        }
        result.move(fromOffsets: moving, toOffset: target)
        return result
    }

    /// The indices a superset spans when its members sit together; nil when they do not, or for an
    /// exercise on its own.
    private static func run(of group: String?, in exercises: [WorkoutTemplateExercise]) -> ClosedRange<Int>? {
        guard let group else { return nil }
        let indices = exercises.indices.filter { exercises[$0].supersetGroupId == group }
        guard let first = indices.first, let last = indices.last, indices.count > 1, indices.count == last - first + 1 else { return nil }
        return first...last
    }

    // MARK: - The plan line

    /// The line under an exercise naming what its plan sets, only the parts set: "3 warm-ups ·
    /// 2:00 rest · 2 alternatives · notes · link · varies by week". Nil when it sets none.
    static func planSummary(for exercise: WorkoutTemplateExercise) -> String? {
        var parts: [String] = []
        if let warmups = exercise.warmupSetCount {
            parts.append(String(localized: "\(warmups) warm-ups"))
        }
        if let rest = exercise.restSeconds, rest > 0 {
            parts.append(String(localized: "\(Format.duration(TimeInterval(rest))) rest"))
        }
        if !exercise.substituteExerciseIds.isEmpty {
            parts.append(String(localized: "\(exercise.substituteExerciseIds.count) alternatives"))
        }
        if let notes = exercise.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(String(localized: "notes"))
        }
        if exercise.linkURL != nil {
            parts.append(String(localized: "link"))
        }
        if !exercise.setTargetsByMicrocycle.isEmpty {
            parts.append(String(localized: "varies by week"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
