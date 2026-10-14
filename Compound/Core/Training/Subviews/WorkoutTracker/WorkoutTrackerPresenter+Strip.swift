//
//  WorkoutTrackerPresenter+Strip.swift
//  Compound
//
//  The exercise strip's side of the presenter: its items, the card's block and a tap on a
//  thumbnail.
//

import Foundation

extension WorkoutTrackerPresenter {

    var stripItems: [ActiveWorkout.StripItem] {
        ActiveWorkout.stripProgress(for: workoutSession.exercises, currentExerciseId: currentExercise?.id)
    }

    /// The card's block, by its first exercise. Also keys the list, so a new block brings a new
    /// list in from the side of the strip it lies on (`CardSwapEdge`).
    var currentBlockId: String? {
        guard let current = currentExercise?.id else { return nil }
        return ActiveWorkout.blocks(workoutSession.exercises).first { $0.contains(current) }?.first
    }

    var blockOrder: [[String]] { ActiveWorkout.blocks(workoutSession.exercises) }

    /// Opens the tapped block on the card; the block already there stays as it is.
    func onStripItemSelected(_ itemId: String) {
        guard itemId != currentBlockId else { return }
        interactor.playHaptic(option: .selection)
        setFocus(itemId, reason: .strip)
    }
}
