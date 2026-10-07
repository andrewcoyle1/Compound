//
//  LiveActivityManager+Pieces.swift
//  Compound
//
//  With Workout Settings › Set Plan on, a drop set or a myo-rep, rest-pause or cluster set is
//  one set logged in pieces: the set's own row, then its drops or mini-sets (`parentSetId`).
//  These rules say which piece the Live Activity's target is, what kind of set it belongs to,
//  and when such a set counts as done. Pure, so they are tested without an activity.
//

import Foundation

extension LiveActivityManager {

    /// Where `target` is among its set's pieces, or nil for a set with none after it.
    static func piece(of target: WorkoutSetModel, in sets: [WorkoutSetModel]) -> SetPiece? {
        let parentId = target.parentSetId ?? target.id
        guard let parent = sets.first(where: { $0.id == parentId }) else { return nil }
        let subSets = ActiveWorkout.subSets(of: parentId, in: sets)
        let pieces = [parent] + subSets
        guard let first = subSets.first, let position = pieces.firstIndex(where: { $0.id == target.id }) else { return nil }
        let word = target.isSubSet ? target : first
        return SetPiece(index: position + 1, count: pieces.count, isDrop: word.subSetKind == .drop)
    }

    /// The kind of the set `target` is, or of the set it is a piece of; nil for a plain set.
    static func kind(of target: WorkoutSetModel, in sets: [WorkoutSetModel]) -> LiveActivitySetKind? {
        let parent = target.parentSetId.flatMap { id in sets.first { $0.id == id } } ?? target
        return LiveActivitySetKind(rawValue: parent.kind.rawValue)
    }

    /// `sets` with every set whose drops or mini-sets are not all logged read as not logged, so a
    /// set counts as done once its last piece is, not its first.
    static func countingPieces(_ sets: [WorkoutSetModel]) -> [WorkoutSetModel] {
        let open = Set(sets.filter { $0.isSubSet && $0.completedAt == nil }.compactMap(\.parentSetId))
        guard !open.isEmpty else { return sets }
        return sets.map { set in
            var set = set
            if open.contains(set.id) { set.completedAt = nil }
            return set
        }
    }
}
