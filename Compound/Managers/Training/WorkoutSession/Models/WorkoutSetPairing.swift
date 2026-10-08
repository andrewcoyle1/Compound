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
    ///
    /// A sub-set (a drop, mini-set or cluster, `isSubSet`) is part of its parent and adds nothing.
    var pairedSetCount: Int {
        var count = 0
        var previousSide: SetSide?
        for set in self where !set.isSubSet {
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
        case .both, nil:
            break
        }
        return [set.id]
    }
}

extension Array where Element == WorkoutSetModel {

    /// Each `both` row as a left and a right row, the figures and the tick copied to each, for when
    /// the sides differ. The left keeps the row's id, so whatever pointed at the set still does.
    func splittingSides() -> [WorkoutSetModel] {
        reindexed(flatMap { set -> [WorkoutSetModel] in
            guard set.side == .both else { return [set] }
            var left = set
            left.side = .left
            let right = WorkoutSetModel(
                id: UUID().uuidString,
                authorId: set.authorId,
                index: set.index,
                reps: set.reps,
                weightKg: set.weightKg,
                durationSec: set.durationSec,
                distanceMeters: set.distanceMeters,
                rpe: set.rpe,
                side: .right,
                kind: set.kind,
                parentSetId: set.parentSetId,
                bands: set.bands,
                isWarmup: set.isWarmup,
                completedAt: set.completedAt,
                dateCreated: set.dateCreated
            )
            return [left, right]
        })
    }

    /// Each left/right pair as one `both` row with the left side's figures. It is ticked only when
    /// both sides were: with one arm still to do, the set is not done.
    func joiningSides() -> [WorkoutSetModel] {
        var joined: [WorkoutSetModel] = []
        for set in self {
            if set.side == .right, let left = joined.last, left.side == .left, !left.isWarmup, !set.isWarmup {
                joined[joined.count - 1].side = .both
                if set.completedAt == nil { joined[joined.count - 1].completedAt = nil }
                continue
            }
            joined.append(set)
        }
        // A left whose right was deleted elsewhere is still a set for both sides.
        return reindexed(joined.map { set in
            var set = set
            if set.side == .left || set.side == .right { set.side = .both }
            return set
        })
    }

    /// Numbered by position, as `addSet` and the detail screen's delete leave them.
    private func reindexed(_ sets: [WorkoutSetModel]) -> [WorkoutSetModel] {
        sets.enumerated().map { position, set in
            var set = set
            set.index = position + 1
            return set
        }
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

    /// Whether the sides are logged apart, a left and a right row per set, rather than one `both`
    /// row. The tracker's Split chip switches between the two.
    var isSplit: Bool {
        sets.contains { !$0.isWarmup && ($0.side == .left || $0.side == .right) }
    }

    /// The rows one more set is made of: a left and a right when split, one `both` row for an
    /// exercise worked a side at a time, otherwise one plain row.
    var sidesPerSet: [SetSide?] {
        if isSplit { return [.left, .right] }
        return isPerSide ? [.both] : [nil]
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

    /// This exercise's row for `set` (a row of `current`) as it was logged last session, matched
    /// on the set number shown and then the side.
    ///
    /// The number, not the stored index: last time may have been split and this time not, and
    /// then the indices no longer line up — set 2 of three `both` rows is index 2, where last
    /// session's index 2 was the right arm of set 1. A limb takes its own side's history first,
    /// then a row done for both sides (or before sides existed), never the other limb's. A row for
    /// both sides takes the left of a split pair, the side `ProgressionPlanner` reads too.
    func matchingSet(for set: WorkoutSetModel, in current: WorkoutExerciseModel) -> WorkoutSetModel? {
        guard !set.isWarmup else {
            return sets.first { $0.index == set.index && $0.side == set.side }
        }
        let number = current.workingSetNumber(for: set)
        let candidates = workingSets.filter { workingSetNumber(for: $0) == number }
        let acceptable: [SetSide?] = switch set.side {
        case .left, .right: [set.side, .both, nil]
        case .both, nil: [.both, nil, .left]
        }
        for side in acceptable {
            if let match = candidates.first(where: { $0.side == side }) { return match }
        }
        return nil
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
