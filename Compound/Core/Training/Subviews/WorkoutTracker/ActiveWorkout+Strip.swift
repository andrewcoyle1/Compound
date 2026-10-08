//
//  ActiveWorkout+Strip.swift
//  Compound
//
//  The exercise strip's rules: one item per block with its working-set progress, and the edge a
//  new block's card comes in from. Behind `WorkoutSettings.showsExerciseStrip`.
//

import SwiftUI

extension ActiveWorkout {

    /// One block on the strip: an exercise, or a superset as one item.
    struct StripItem: Identifiable, Equatable {
        /// The block's first exercise, which a tap opens.
        let id: String
        let names: [String]
        /// One per member, in the same order as `names`, drawn side by side for a superset.
        let imageNames: [String?]
        /// "A", "B"… for supersets in workout order; `nil` for an exercise on its own.
        let supersetLetter: String?
        /// Working sets only, a left/right pair counted once, as the header counts them.
        let doneWorkingSets: Int
        let totalWorkingSets: Int
        let isCurrent: Bool

        var isComplete: Bool { totalWorkingSets > 0 && doneWorkingSets >= totalWorkingSets }

        var fraction: Double {
            totalWorkingSets == 0 ? 0 : Double(doneWorkingSets) / Double(totalWorkingSets)
        }
    }

    /// The strip, block by block in workout order (`blocks(_:)`), with the block holding
    /// `currentExerciseId` marked current.
    static func stripProgress(for exercises: [WorkoutExerciseModel], currentExerciseId: String?) -> [StripItem] {
        let byId = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var supersetCount = 0
        return blocks(exercises).compactMap { block in
            let members = block.compactMap { byId[$0] }
            guard let first = members.first else { return nil }
            var letter: String?
            if members.count > 1 {
                letter = supersetLetter(supersetCount)
                supersetCount += 1
            }
            let working = members.map { $0.sets.filter { !$0.isWarmup } }
            return StripItem(
                id: first.id,
                names: members.map(\.name),
                imageNames: members.map(\.imageName),
                supersetLetter: letter,
                doneWorkingSets: working.reduce(0) { $0 + $1.fullyCompletedPairedSetCount },
                totalWorkingSets: working.reduce(0) { $0 + $1.pairedSetCount },
                isCurrent: block.contains(currentExerciseId ?? "")
            )
        }
    }

    private static func supersetLetter(_ index: Int) -> String? {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return letters.indices.contains(index) ? String(letters[index]) : nil
    }

    /// The edge the card comes in from when it moves from exercise `from` to exercise `to`:
    /// `.trailing` going forward in `order` (the workout's blocks), `.leading` going back. Within
    /// one block, or for an exercise not in `order` (just added or swapped in), forward.
    static func entryEdge(from: String?, to target: String?, order: [[String]]) -> Edge {
        guard let fromIndex = order.firstIndex(where: { $0.contains(from ?? "") }),
              let toIndex = order.firstIndex(where: { $0.contains(target ?? "") }) else { return .trailing }
        return toIndex < fromIndex ? .leading : .trailing
    }
}
