//
//  ActiveWorkout+SetKind.swift
//  Compound
//
//  Set kinds on the card: what the set-number menu offers and what a pick there does, where a
//  drop or mini-set goes, what deleting a set takes with it, what its rows are called, and which
//  of last time's rows its Last column shows. The model is in `SetKind.swift`; this is how the
//  tracker uses it.
//

import Foundation

/// What a sub-row is called on the card. A drop changes the weight; a mini-set is a myo-rep,
/// rest-pause or cluster round after a short breath at the same weight.
enum SubSetKind: Equatable {
    case drop
    case mini
}

/// A line of the set-number menu: a kind, or a warm-up, which is a flag on the set rather than a
/// kind of its own.
enum SetTypeChoice: Hashable {
    case warmup
    case kind(SetKind)

    var displayName: String {
        switch self {
        case .warmup: String(localized: "Warm-up")
        case .kind(let kind): kind.displayName
        }
    }

    /// The choice as analytics records it.
    var eventValue: String {
        switch self {
        case .warmup: "warmup"
        case .kind(let kind): kind.rawValue
        }
    }
}

extension WorkoutSetModel {

    /// What the set-number menu ticks for this set.
    var typeChoice: SetTypeChoice { isWarmup ? .warmup : .kind(kind) }

    /// `nil` for a set of its own. A sub-row stored as `.standard` is a mini-set, whose rest
    /// follows its parent's kind (`RestDurationRules`), so it keeps up when the parent's changes.
    var subSetKind: SubSetKind? {
        guard isSubSet else { return nil }
        return kind == .drop ? .drop : .mini
    }
}

extension SetKind {

    /// The name the Set Type picker gives the kind.
    var displayName: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .drop: String(localized: "Drop Set")
        case .amrap: String(localized: "Failure Set")
        case .myo: String(localized: "Myo Set")
        case .restPause: String(localized: "Rest-pause")
        case .cluster: String(localized: "Cluster")
        case .partials: String(localized: "Lengthened partials")
        case .stretch: String(localized: "Loaded stretch")
        case .hold: String(localized: "Static hold")
        }
    }

    /// "Partials", "Stretch", "Hold": the piece after a set of these kinds, on its chip and in its
    /// row's name. Nil for every other kind, whose pieces are drops or mini-sets.
    var pieceName: String? {
        switch self {
        case .partials: String(localized: "Partials")
        case .stretch: String(localized: "Stretch")
        case .hold: String(localized: "Hold")
        case .standard, .drop, .amrap, .myo, .restPause, .cluster: nil
        }
    }
}

extension ActiveWorkout {

    // MARK: - The set-number menu

    /// The types the set number's menu offers. A set a plan made another kind (rest-pause, a
    /// cluster, partials…) keeps that kind at the end, so the menu still ticks what it is.
    static func setTypeOptions(for set: WorkoutSetModel) -> [SetTypeChoice] {
        let options: [SetTypeChoice] = [.kind(.standard), .warmup, .kind(.drop), .kind(.myo), .kind(.amrap)]
        return options.contains(set.typeChoice) ? options : options + [set.typeChoice]
    }

    /// Whether the set number opens the type menu: not on a sub-row, which is part of its set.
    static func offersSetTypes(_ set: WorkoutSetModel) -> Bool {
        !set.isSubSet
    }

    /// Another drop belongs to a drop set.
    static func offersDrop(_ set: WorkoutSetModel) -> Bool {
        !set.isWarmup && !set.isSubSet && set.kind == .drop
    }

    /// A mini-set belongs to a set that rests within itself: myo-reps, rest-pause or a cluster.
    static func offersMiniSet(_ set: WorkoutSetModel) -> Bool {
        !set.isWarmup && !set.isSubSet && set.kind.restsWithinTheSet
    }

    /// `sets` with `setId`, and the other half of its pair, made `choice`.
    ///
    /// Sub-rows the new type has no use for go: every one for a warm-up, a standard or a failure
    /// set, the mini-sets of a set made a drop set and the drops of one made a myo set. A drop or
    /// myo set left with none is given its first under `setId`, as Add Another would add it: a
    /// drop at `dropWeightKg`, a mini-set at the set's weight.
    static func applying(
        _ choice: SetTypeChoice,
        to setId: String,
        in sets: [WorkoutSetModel],
        firstSubSetId: String,
        dropWeightKg: Double?
    ) -> [WorkoutSetModel] {
        guard let set = sets.first(where: { $0.id == setId }), set.typeChoice != choice else { return sets }
        let family = Set(sets.pairedSetIds(for: setId))
        let kind: SetKind = if case .kind(let kind) = choice { kind } else { .standard }
        let subKind: SubSetKind? = choice == .warmup ? nil : kind == .drop ? .drop : kind.restsWithinTheSet ? .mini : nil

        var updated = sets.filter { row in
            guard let parentId = row.parentSetId, family.contains(parentId) else { return true }
            // A drop is stored as one; a mini-set is stored plain. Partials and the like are neither.
            return switch subKind {
            case .drop: row.kind == .drop
            case .mini: row.kind == .standard
            case nil: false
            }
        }
        for index in updated.indices where family.contains(updated[index].id) {
            updated[index].isWarmup = choice == .warmup
            updated[index].kind = kind
        }
        guard let subKind, subSets(of: setId, in: updated).isEmpty else { return updated }
        return addingSubSet(subKind, to: setId, in: updated, id: firstSubSetId, weightKg: subKind == .drop ? dropWeightKg : set.weightKg)
    }

    // MARK: - Sub-rows

    /// The drops and mini-sets of `parentId`, in the order they are done.
    static func subSets(of parentId: String, in sets: [WorkoutSetModel]) -> [WorkoutSetModel] {
        sets.filter { $0.parentSetId == parentId }
    }

    /// Where a new sub-row of `parentId` goes: under the set, after any sub-rows it already has.
    /// For half of a left/right pair, after the pair and both halves' sub-rows, so the pair stays
    /// side by side and is never split by a drop.
    static func subSetInsertionIndex(parentId: String, in sets: [WorkoutSetModel]) -> Int? {
        let family = Set(sets.pairedSetIds(for: parentId))
        guard !family.isEmpty else { return nil }
        let last = sets.lastIndex { family.contains($0.id) || family.contains($0.parentSetId ?? "") }
        return last.map { $0 + 1 }
    }

    /// `sets` with a new drop or mini-set of `parentId` in place, reps empty. It takes the
    /// parent's side, so a drop on the left arm is the left arm's. A mini-set is stored plain, and
    /// rests as its parent's kind does.
    static func addingSubSet(
        _ subKind: SubSetKind,
        to parentId: String,
        in sets: [WorkoutSetModel],
        id: String,
        weightKg: Double?
    ) -> [WorkoutSetModel] {
        guard let parent = sets.first(where: { $0.id == parentId }),
              let position = subSetInsertionIndex(parentId: parentId, in: sets) else { return sets }
        let subSet = WorkoutSetModel(
            id: id,
            authorId: parent.authorId,
            // One past the highest, as Add Set numbers a set: indices are what warm-ups are matched on.
            index: (sets.map(\.index).max() ?? 0) + 1,
            weightKg: weightKg,
            side: parent.side,
            kind: subKind == .drop ? .drop : .standard,
            parentSetId: parent.id,
            isWarmup: false,
            dateCreated: .now
        )
        var sets = sets
        sets.insert(subSet, at: position)
        return sets
    }

    /// A drop's starting weight: `percent` (20 %) off its parent, to the nearest weight the
    /// equipment makes, and lighter than the parent even where the nearest is the parent itself.
    /// 20 % rather than one gym step, because a 2.5 kg step off a barbell is no drop at all.
    /// Assistance (a negative weight) and no weight are left as they are.
    static func dropWeightKg(from parentKg: Double?, step: WeightStep, unit: ExerciseWeightUnit, percent: Int = 20) -> Double? {
        guard let parentKg, parentKg > 0 else { return parentKg }
        let parent = UnitConversion.convertWeight(parentKg, to: unit)
        var snapped = step.nearest(to: parent * (1 - Double(percent) / 100))
        if snapped >= parent - WeightStep.epsilon, let lighter = step.previous(before: parent), lighter < parent - WeightStep.epsilon {
            snapped = lighter
        }
        return UnitConversion.convertWeightToKg(snapped, from: unit)
    }

    /// The ids deleting `setId` removes: the set, the other half of its pair, and every drop and
    /// mini-set of either. A drop left behind would claim a parent that is gone.
    static func idsRemovedByDeleting(_ setId: String, in sets: [WorkoutSetModel]) -> [String] {
        let rows = sets.pairedSetIds(for: setId)
        let family = Set(rows)
        return rows + sets.filter { family.contains($0.parentSetId ?? "") }.map(\.id)
    }

    /// How many drops and mini-sets deleting `setId` takes with it, a left/right pair of them
    /// counted once, as sets are.
    static func subSetsRemovedByDeleting(_ setId: String, in sets: [WorkoutSetModel]) -> (drops: Int, minis: Int) {
        let removed = Set(idsRemovedByDeleting(setId, in: sets))
        let subSets = sets.filter { removed.contains($0.id) && $0.isSubSet }
            .filter { !($0.side == .right && sets.pairedSetIds(for: $0.id).count == 2) }
        return (subSets.filter { $0.subSetKind == .drop }.count, subSets.filter { $0.subSetKind == .mini }.count)
    }

    /// The sub-row's place among its parent's sub-rows of the same kind and side, from 1: drop 2
    /// is the second drop. A drop split into a left and a right row is drop 1 on each side. 0 for
    /// a set of its own.
    static func subSetOrdinal(of set: WorkoutSetModel, in sets: [WorkoutSetModel]) -> Int {
        guard let parentId = set.parentSetId else { return 0 }
        let siblings = subSets(of: parentId, in: sets).filter { $0.subSetKind == set.subSetKind && $0.side == set.side }
        return (siblings.firstIndex { $0.id == set.id } ?? -1) + 1
    }

    /// "drop set 1", "mini-set 2", "Partials": a sub-row's name after its parent's.
    static func subSetName(of set: WorkoutSetModel, in sets: [WorkoutSetModel]) -> String? {
        guard let subKind = set.subSetKind else { return nil }
        if let pieceName = set.kind.pieceName { return pieceName }
        let ordinal = subSetOrdinal(of: set, in: sets)
        return switch subKind {
        case .drop: String(localized: "drop set \(ordinal)")
        case .mini: String(localized: "mini-set \(ordinal)")
        }
    }

    // MARK: - Last

    /// Last session's row for `set`, a row of `current`. A set of its own is matched among last
    /// time's sets of their own, on its number and side (`matchingSet`). A drop or mini-set is
    /// matched on its parent's match, its kind and its place: last time's second drop of that set
    /// for this set's second drop, and never the parent's own figures, which a drop is lighter than.
    static func lastSet(for set: WorkoutSetModel, in current: WorkoutExerciseModel, last: WorkoutExerciseModel?) -> WorkoutSetModel? {
        guard let last else { return nil }
        guard let parentId = set.parentSetId else {
            var lastSets = last
            lastSets.sets = last.sets.filter { !$0.isSubSet }
            return lastSets.matchingSet(for: set, in: current)
        }
        guard let parent = current.sets.first(where: { $0.id == parentId }),
              !parent.isSubSet,
              let lastParent = lastSet(for: parent, in: current, last: last) else { return nil }
        let ordinal = subSetOrdinal(of: set, in: current.sets)
        let candidates = subSets(of: lastParent.id, in: last.sets).filter { $0.subSetKind == set.subSetKind }
        // A limb takes its own side first, then a row for both; a row for both takes the left.
        let sides: [SetSide?] = switch set.side {
        case .left, .right: [set.side, .both, nil]
        case .both, nil: [.both, nil, .left]
        }
        for side in sides {
            if let match = candidates.first(where: { $0.side == side && subSetOrdinal(of: $0, in: last.sets) == ordinal }) {
                return match
            }
        }
        return nil
    }
}
