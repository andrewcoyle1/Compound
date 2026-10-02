//
//  WorkoutSetPairing.swift
//  Compound
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Foundation

/// A left set and a right set are one set, not two.
///
/// Three sets of a single-arm row are logged as six rows, because six efforts happened and each
/// deserves its own weight and reps. But the user did three sets, so every place that shows a set
/// count — "Set 2 of 3", the Live Activity, the feed row, weekly sets per muscle — has to say
/// three. Volume is the exception and is deliberately left alone: six tens at twenty kilos really
/// is six tens at twenty kilos of work.
///
/// Everything that counts sets goes through `pairedSetCount` so there is one rule, in one place.
extension Collection where Element == WorkoutSetModel {

    /// How many sets these rows amount to, counting a left/right pair as the one set it is.
    ///
    /// Pairs are stored next to each other, left first, so a right set is folded into the left set
    /// that precedes it and every other row counts for itself. Filtering first is safe: a right
    /// set whose left partner was filtered out — a pair half finished, say — still counts as one,
    /// which is what "sets done so far" should say after the first limb.
    var pairedSetCount: Int {
        var count = 0
        var previousSide: SetSide?
        for set in self {
            if !(set.side == .right && previousSide == .left) {
                count += 1
            }
            previousSide = set.side
        }
        return count
    }

    /// How many sets are fully done, a pair counting only once both halves are. The tracker lets
    /// the user tick the right side first, so both sides are checked.
    ///
    /// `pairedSetCount` on the completed rows alone reads a lone left row as a finished set, which
    /// is right for "the set the user is on" (`loggedSetCount`) and wrong for "is the work done":
    /// it would put the banner on "Set 2 of 4" with the right arm of set 1 still to come, and offer
    /// Finish with the last row of the workout unlogged.
    var fullyCompletedPairedSetCount: Int {
        filter { row in
            guard row.completedAt != nil else { return false }
            let pair = pairedSetIds(for: row.id)
            guard pair.count == 2,
                  let partnerId = pair.first(where: { $0 != row.id }),
                  let partner = first(where: { $0.id == partnerId }) else { return true }
            return partner.completedAt != nil
        }.pairedSetCount
    }

    /// The ids of every row making up the same set as `setId`: itself, plus the opposite side when
    /// it is half of a pair.
    ///
    /// Adding and deleting work on this, so a side can never be orphaned — a lone right set would
    /// number and rest as a set of its own and quietly claim to be one.
    func pairedSetIds(for setId: String) -> [String] {
        let sets = Array(self)
        guard let position = sets.firstIndex(where: { $0.id == setId }) else { return [] }
        let set = sets[position]

        switch set.side {
        case .left:
            let next = position + 1
            if next < sets.count, sets[next].side == .right, !sets[next].isWarmup {
                return [set.id, sets[next].id]
            }
        case .right:
            let previous = position - 1
            if previous >= 0, sets[previous].side == .left, !sets[previous].isWarmup {
                return [sets[previous].id, set.id]
            }
        case nil:
            break
        }
        return [set.id]
    }
}

extension WorkoutExerciseModel {

    /// The sets that count as work, warm-ups excluded.
    var workingSets: [WorkoutSetModel] {
        sets.filter { !$0.isWarmup }
    }

    /// Whether this exercise is worked one limb at a time, read off the rows it already carries.
    ///
    /// `WorkoutSessionModel.isPerSide` answers the same question from the `ExerciseModel`, which a
    /// logged session does not keep — its sets are the only surviving record of how it was tracked,
    /// so a set added afterwards follows them rather than guessing.
    var isPerSide: Bool {
        sets.contains { !$0.isWarmup && $0.side != nil }
    }

    /// How many working sets this exercise asks for, pairs counted once.
    var workingSetCount: Int {
        workingSets.pairedSetCount
    }

    /// How many working sets have been logged, pairs counted once. A pair counts from the moment
    /// either limb is done — the user is on set two once the left side of set one is behind them.
    var loggedSetCount: Int {
        sets.filter { !$0.isWarmup && $0.completedAt != nil }.pairedSetCount
    }

    /// The number this set is shown as: the set the user is on, not the row's position. A pair
    /// shares its number and is told apart by the L/R marker beside it, so a per-side exercise
    /// reads 1L, 1R, 2L, 2R rather than 1 through 4.
    ///
    /// Warm-ups are numbered "W" wherever they are shown, so they never reach this.
    func workingSetNumber(for set: WorkoutSetModel) -> Int {
        var upToAndIncluding: [WorkoutSetModel] = []
        for candidate in workingSets {
            upToAndIncluding.append(candidate)
            if candidate.id == set.id { break }
        }
        return upToAndIncluding.pairedSetCount
    }

    /// This exercise's row for `set` as it was logged last session, matched on the set number and
    /// the side. Falls back to a sideless row of the same number, which is everything logged
    /// before sides existed.
    func matchingSet(for set: WorkoutSetModel) -> WorkoutSetModel? {
        if let exact = sets.first(where: { $0.index == set.index && $0.side == set.side }) {
            return exact
        }
        guard set.side != nil else { return nil }
        return sets.first { $0.index == set.index && $0.side == nil }
    }
}

/// What last session's figures are matched on.
///
/// The index alone is not enough once sets have sides: a left set inheriting the right side's
/// weight is showing the user the wrong arm's history, and they will chase it.
struct PreviousSetKey: Hashable {
    let index: Int
    let side: SetSide?

    init(index: Int, side: SetSide?) {
        self.index = index
        self.side = side
    }

    init(_ set: WorkoutSetModel) {
        self.init(index: set.index, side: set.side)
    }
}

extension Dictionary where Key == PreviousSetKey, Value == WorkoutSetModel {

    /// Last session's matching set, if there is one.
    ///
    /// Falls back to the sideless entry for the same index, because everything logged before sides
    /// existed has no side at all — that history belongs to both limbs rather than to neither, and
    /// dropping it would blank the previous column for every set of every unilateral exercise.
    func match(for set: WorkoutSetModel) -> WorkoutSetModel? {
        if let exact = self[PreviousSetKey(set)] { return exact }
        guard set.side != nil else { return nil }
        return self[PreviousSetKey(index: set.index, side: nil)]
    }
}
