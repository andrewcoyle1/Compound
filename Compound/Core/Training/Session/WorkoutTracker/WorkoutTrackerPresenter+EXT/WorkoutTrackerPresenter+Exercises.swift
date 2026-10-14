//
//  WorkoutTrackerPresenter+Exercises.swift
//  Compound
//
//  The workout's exercises: adding from the picker, deleting, reordering (Do Later, Do Next,
//  the strip), swapping, and supersets.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    /// Exercises picked part-way through, set up as the workout's own were: a unilateral lift
    /// gets rows it can split, and each gets last time's sets and a suggestion. The card stays
    /// on the exercise being worked.
    func addSelectedExercises() {
        let templates = self.pendingSelectedTemplates
        guard !templates.isEmpty, let userId = interactor.currentUser?.userId else { return }
        var updated = workoutSession.exercises
        let startIndex = updated.count
        var added: [WorkoutExerciseModel] = []
        for (offset, template) in templates.enumerated() {
            let index = startIndex + offset + 1
            let exercise = template.exercise
            let mode = WorkoutSessionModel.trackingMode(for: exercise)
            let targetCount = max(template.setTargets.count, 1)
            let defaultSets = WorkoutSessionModel.defaultSets(
                trackingMode: mode,
                authorId: userId,
                targetCount: targetCount,
                perSide: WorkoutSessionModel.isPerSide(exercise),
                setTargets: template.setTargets
            )
            let imageName = Constants.exerciseImageName(for: exercise)
            var newExercise = WorkoutExerciseModel(
                id: UUID().uuidString,
                authorId: userId,
                templateId: exercise.id,
                name: exercise.name,
                trackingMode: mode,
                index: index,
                notes: nil,
                imageName: imageName,
                sets: defaultSets,
                setTargets: template.setTargets
            )
            newExercise.takeLoad(
                from: exercise,
                gym: interactor.workoutGymProfile,
                preference: interactor.getPreference(templateId: exercise.id)
            )
            updated.append(newExercise)
            added.append(newExercise)
        }
        let card = currentExercise?.id ?? added.first?.id
        workoutSession.updateExercises(updated)
        focusCard(on: card)
        captureProgressionBaseline(of: added)
        loadPrevious(for: added)
        loadProgressionSuggestions(for: added)
        interactor.playHaptic(option: .success)
        interactor.trackEvent(event: Event.exercisesAdded(count: added.count))

        refreshLiveActivity()

        self.pendingSelectedTemplates = []
    }

    /// Takes the exercise out. A superset partner left on its own is no longer a superset, and a
    /// card on the deleted exercise moves to the next one in the workout's order with sets left.
    /// A rest that followed one of its sets is called off by `cancelRestIfRestedSetRemoved`.
    func deleteExercise(_ exerciseId: String) {
        var updated = workoutSession.exercises
        guard let idx = updated.firstIndex(where: { $0.id == exerciseId }) else { return }
        let removed = updated.remove(at: idx)
        if let groupId = removed.supersetGroupId {
            let partners = updated.indices.filter { updated[$0].supersetGroupId == groupId }
            if partners.count == 1 { updated[partners[0]].supersetGroupId = nil }
        }
        for index in updated.indices { updated[index].index = index + 1 }

        var card = currentExercise?.id
        if card == exerciseId {
            let next = updated.indices.first { $0 >= idx && !isComplete(updated[$0]) }
                ?? updated.indices.first { !isComplete(updated[$0]) }
            card = next.map { updated[$0].id }
        }
        workoutSession.updateExercises(updated)
        focusCard(on: card)
        interactor.playHaptic(option: .success)
        interactor.trackEvent(event: Event.exerciseDeleted)

        refreshLiveActivity()
    }

    /// Puts the card on `exerciseId`, or back on the first exercise with sets left without one.
    private func focusCard(on exerciseId: String?) {
        let exercises = workoutSession.exercises
        if let exerciseId, let index = exercises.firstIndex(where: { $0.id == exerciseId }) {
            cardExerciseId = exerciseId
            currentExerciseIndex = index
        } else {
            cardExerciseId = nil
            syncCurrentExerciseIndexToFirstIncomplete(in: exercises)
        }
    }

    func setSupersetGroupId(_ groupId: String?, forExerciseId exerciseId: String) {
        guard var exercise = workoutSession.exercises.first(where: { $0.id == exerciseId }) else { return }
        exercise.supersetGroupId = groupId
        replaceExercise(exercise)
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: Event.supersetChanged(joined: groupId != nil))
    }

    /// A set more for every member of a superset (`WorkoutExerciseModel.addingSet`), as one round.
    func onAddRoundPressed(_ memberIds: [String]) {
        guard let userId = interactor.currentUser?.userId else { return }
        let ids = Set(memberIds)
        workoutSession.updateExercises(workoutSession.exercises.map {
            ids.contains($0.id) ? $0.addingSet(authorId: userId) : $0
        })
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: Event.roundAdded)
    }

    /// Splits a superset, or a circuit, back into exercises on their own, all at once.
    func removeSuperset(_ memberIds: [String]) {
        let ids = Set(memberIds)
        workoutSession.updateExercises(workoutSession.exercises.map { exercise in
            var exercise = exercise
            if ids.contains(exercise.id) { exercise.supersetGroupId = nil }
            return exercise
        })
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: Event.supersetChanged(joined: false))
    }

    /// Writes back an edited exercise, by id: the card's binding, a superset change, an undo. By
    /// id, not index, because a binding by index can be read while the exercise it held is being
    /// removed, and would then point at another exercise or past the end.
    func replaceExercise(_ updated: WorkoutExerciseModel) {
        guard let index = workoutSession.exercises.firstIndex(where: { $0.id == updated.id }) else { return }
        var exercises = workoutSession.exercises
        exercises[index] = updated
        workoutSession.updateExercises(exercises)
    }

    func onAddExercisePressed() {
        router.showExercisesPickerView(
            delegate: ExercisesPickerDelegate(
                addedExercises: Binding(
                    get: { self.pendingSelectedTemplates },
                    set: {
                        self.pendingSelectedTemplates = $0
                        self.addSelectedExercises()
                    }
                )
            )
        )
    }

    // MARK: - Reordering

    /// Whether `exercise` can be put off: it has sets left and something else could go first.
    func canDoLater(_ exercise: WorkoutExerciseModel) -> Bool {
        let group = Set(movingGroup(for: exercise.id).map(\.id))
        return !isComplete(exercise) && workoutSession.exercises.contains { !group.contains($0.id) && !isComplete($0) }
    }

    /// A busy machine: the exercise, with any superset partners, goes to the end of the workout.
    /// Put off from the card, the card moves on to the next exercise with sets left.
    func onDoLaterPressed(_ exerciseId: String) {
        let group = movingGroup(for: exerciseId)
        let ids = Set(group.map(\.id))
        let wasOnCard = ids.contains(currentExercise?.id ?? "")
        move(group, toIndex: workoutSession.exercises.filter { !ids.contains($0.id) }.count)
        if wasOnCard, let next = workoutSession.exercises.first(where: { !ids.contains($0.id) && !isComplete($0) }) {
            cardExerciseId = next.id
            currentExerciseIndex = workoutSession.exercises.firstIndex { $0.id == next.id } ?? currentExerciseIndex
        }
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: Event.exerciseMoved(later: true))
        refreshLiveActivity()
    }

    /// Straight after the exercise on the card, with any superset partners.
    func onDoNextPressed(_ exerciseId: String) {
        let group = movingGroup(for: exerciseId)
        let ids = Set(group.map(\.id))
        let others = workoutSession.exercises.filter { !ids.contains($0.id) }
        let currentGroup = Set(movingGroup(for: currentExercise?.id ?? "").map(\.id))
        let insertAt = (others.lastIndex { currentGroup.contains($0.id) }).map { $0 + 1 } ?? 0
        move(group, toIndex: insertAt)
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: Event.exerciseMoved(later: false))
        refreshLiveActivity()
    }

    /// An exercise and its superset partners, in workout order: a superset is done as one.
    private func movingGroup(for exerciseId: String) -> [WorkoutExerciseModel] {
        guard let exercise = workoutSession.exercises.first(where: { $0.id == exerciseId }) else { return [] }
        guard let groupId = exercise.supersetGroupId else { return [exercise] }
        return workoutSession.exercises.filter { $0.supersetGroupId == groupId }
    }

    /// A thumbnail dropped on another's place on the strip, or moved a step by Move Earlier/Later
    /// in its menu or VoiceOver's actions: the block goes to `index` among the other blocks, as one.
    /// The card stays on the exercise it showed; the new place is announced, as the thumbnail
    /// moves out from under VoiceOver's focus.
    func onStripItemMoved(_ blockId: String, toBlockIndex index: Int) {
        let updated = ActiveWorkout.movingBlock(blockId, toBlockIndex: index, in: workoutSession.exercises)
        guard updated.map(\.id) != workoutSession.exercises.map(\.id) else { return }
        let from = blockOrder.firstIndex { $0.first == blockId } ?? 0
        reorder(to: updated)
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: Event.exerciseReordered(fromBlock: from, toBlock: index))
        refreshLiveActivity()
        let position = (blockOrder.firstIndex { $0.first == blockId } ?? index) + 1
        announce(TrackerAnnouncement(text: String(localized: "Position \(position) of \(blockOrder.count)")))
    }

    /// Puts `group` at `index` among the other exercises, keeping the card where it was.
    private func move(_ group: [WorkoutExerciseModel], toIndex index: Int) {
        let ids = Set(group.map(\.id))
        var updated = workoutSession.exercises.filter { !ids.contains($0.id) }
        updated.insert(contentsOf: group, at: min(index, updated.count))
        reorder(to: updated)
    }

    /// Applies a new order and puts the card back on the exercise it showed.
    private func reorder(to updated: [WorkoutExerciseModel]) {
        let card = currentExercise?.id
        applyReorderedExercises(updated)
        if let card, let cardIndex = updated.firstIndex(where: { $0.id == card }) {
            cardExerciseId = card
            currentExerciseIndex = cardIndex
        }
    }

    func applyReorderedExercises(_ updated: [WorkoutExerciseModel]) {
        var updated = updated
        // Reindex exercises only (do not touch set indices)
        for idx in updated.indices {
            updated[idx].index = idx + 1
        }

        // Always align current exercise to top-most incomplete after reorders
        workoutSession.updateExercises(updated)
        syncCurrentExerciseIndexToFirstIncomplete(in: updated)
    }

    /// True when the exercise has sets and every one of them is logged.
    func isComplete(_ exercise: WorkoutExerciseModel) -> Bool {
        !exercise.sets.isEmpty && exercise.sets.allSatisfy { $0.completedAt != nil }
    }

    // MARK: - Swap

    /// Swaps the exercise `exerciseId` for `replacement`.
    ///
    /// Logged sets stay where they were done: two logged sets of barbell bench do not become
    /// dumbbell bench in the history. That exercise keeps only them, so it reads as done, and the
    /// replacement goes in right after it with the sets that were still open. With nothing logged
    /// there is nothing to keep, and the replacement takes the exercise's place. Either way the
    /// card moves to the replacement, and last time's figures and smart progression's suggestions
    /// are loaded for it, since both are keyed by the exercise's template.
    func insertSwappedExercise(after exerciseId: String, new replacement: ExerciseModel) {
        guard let authorId = interactor.currentUser?.userId,
              let index = workoutSession.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }

        var swap = Self.swapping(workoutSession.exercises[index], to: replacement, authorId: authorId)
        swap.replacement.takeLoad(
            from: replacement,
            gym: interactor.workoutGymProfile,
            preference: interactor.getPreference(templateId: replacement.id)
        )
        var exercises = workoutSession.exercises
        if let kept = swap.kept {
            exercises[index] = kept
            exercises.insert(swap.replacement, at: index + 1)
        } else {
            exercises[index] = swap.replacement
        }
        for position in exercises.indices { exercises[position].index = position + 1 }

        workoutSession.updateExercises(exercises)
        cardExerciseId = swap.replacement.id
        currentExerciseIndex = exercises.firstIndex { $0.id == swap.replacement.id } ?? currentExerciseIndex
        loadPreviousWorkoutSession()
        loadProgressionSuggestions()
        interactor.playHaptic(option: .success)
        interactor.trackEvent(event: Event.exerciseSwapped(keptLoggedSets: swap.kept != nil))
        refreshLiveActivity()
    }

    /// The swap itself, pure. `kept` is the old exercise holding only its logged sets, or `nil`
    /// when none were logged and the replacement simply takes its place (keeping its id).
    ///
    /// The replacement has as many working sets as were open, a left/right pair counted once and
    /// open warm-ups not at all: a warm-up for the old lift is not a working set of the new one.
    /// Three when none were open. It takes the targets of those open sets, renumbered from one, the
    /// old exercise's place in a superset, and the plan's notes, rest, link and alternatives: the
    /// plan is for the slot, whichever lift fills it.
    static func swapping(
        _ old: WorkoutExerciseModel,
        to replacement: ExerciseModel,
        authorId: String
    ) -> (kept: WorkoutExerciseModel?, replacement: WorkoutExerciseModel) {
        let logged = old.sets.filter { $0.completedAt != nil }
        let openCount = old.sets.filter { $0.completedAt == nil && !$0.isWarmup }.pairedSetCount
        let perSide = WorkoutSessionModel.isPerSide(replacement)
        let mode = WorkoutSessionModel.trackingMode(for: replacement)

        var sets = WorkoutSessionModel.defaultSets(
            trackingMode: mode,
            authorId: authorId,
            targetCount: openCount > 0 ? openCount : 3,
            perSide: perSide
        )
        if perSide && old.isSplit { sets = sets.splittingSides() }

        let loggedCount = old.loggedSetCount
        var targets = old.setTargets
            .filter { $0.setNumber > loggedCount }
            .map { target in
                var target = target
                target.setNumber -= loggedCount
                return target
            }
        if targets.isEmpty { targets = [SetTarget.standard(setNumber: 1)] }

        let new = WorkoutExerciseModel(
            id: logged.isEmpty ? old.id : UUID().uuidString,
            authorId: authorId,
            templateId: replacement.id,
            name: replacement.name,
            trackingMode: mode,
            index: old.index + (logged.isEmpty ? 0 : 1),
            imageName: Constants.exerciseImageName(for: replacement),
            sets: sets,
            setTargets: targets,
            equipmentVariations: replacement.equipmentVariations,
            supersetGroupId: old.supersetGroupId,
            planNotes: old.planNotes,
            planSlotId: old.planSlotId,
            restSeconds: old.restSeconds,
            linkURL: old.linkURL,
            substituteExerciseIds: old.substituteExerciseIds
        )
        guard !logged.isEmpty else { return (nil, new) }

        var kept = old
        kept.sets = logged
        kept.supersetGroupId = nil
        return (kept, new)
    }
}
