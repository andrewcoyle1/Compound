//
//  WorkoutTrackerPresenter+Card.swift
//  Compound
//
//  What the exercise card shows beyond its sets: units, the bodyweight badge, smart
//  progression's note, a superset's card and the rest row.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    /// The exercise's units, its weight unit as this session enters it (`WorkoutExerciseModel.weightUnit`).
    func units(for exercise: WorkoutExerciseModel) -> ExerciseUnitPreference {
        exercise.units(interactor.getPreference(templateId: exercise.templateId))
    }

    /// The bodyweight `exercise` lifts, for its badge and "BW" labels: `nil` with the setting off or
    /// for a movement that lifts none.
    func bodyweightContribution(for exercise: WorkoutExerciseModel) -> BodyweightContribution? {
        guard showBodyweightContribution else { return nil }
        // ponytail: today's bodyweight, not the session's, so a workout reopened later reads at
        // whatever the scale says then; snapshot it onto the session if history must stay fixed.
        // Read from the library once per exercise rather than on every keystroke.
        if bodyweightPercents[exercise.templateId] == nil {
            let library = interactor.allExercises
            for templateId in Set(workoutSession.exercises.map(\.templateId) + [exercise.templateId]) {
                bodyweightPercents[templateId] = library.first { $0.id == templateId }?.bodyWeightContribution ?? 0
            }
        }
        guard let percent = bodyweightPercents[exercise.templateId], percent > 0 else { return nil }
        return BodyweightContribution(percent: percent, bodyweightKg: interactor.currentWeightKilograms, unit: units(for: exercise).weightUnit)
    }

    func progressionReason(for exercise: WorkoutExerciseModel) -> String? {
        ActiveWorkout.progressionReason(
            suggestion: progressionSuggestion(for: exercise),
            planned: exercise,
            last: previousExercise(for: exercise),
            unit: units(for: exercise).weightUnit
        )
    }

    /// Smart progression's reason for the exercise on the card, shown over the log button when
    /// the exercise is started, until it is acknowledged or the first working set is logged: by
    /// then the user has acted on it. Acknowledged by template, as the suggestion it speaks
    /// for is kept. Sets logged from the Lock Screen while the screen was away take the slot
    /// first, until the next action (see `logReceipt`). With the set plan on, an exercise that
    /// opens with drops, mini-sets or an AMRAP target says what they are after the reason
    /// (`ActiveWorkout.planSummary`), acknowledged with it.
    var progressionNote: String? {
        if let logReceipt { return logReceipt }
        guard let exercise = currentExercise,
              !acknowledgedProgressionNotes.contains(exercise.templateId),
              exercise.loggedSetCount == 0 else { return nil }
        let plan = interactor.workoutSettings.plansSets
            ? ActiveWorkout.planSummary(for: exercise, unit: units(for: exercise).weightUnit)
            : nil
        let note = [progressionReason(for: exercise), plan].compactMap { $0 }
        return note.isEmpty ? nil : note.joined(separator: " ")
    }

    /// The note on `exercise`'s card: smart progression's note speaks for the exercise the log
    /// button is on, so a superset's other members show none.
    func progressionNote(for exercise: WorkoutExerciseModel) -> String? {
        exercise.id == currentExercise?.id ? progressionNote : nil
    }

    func onProgressionNoteAcknowledged() {
        // The receipt sits in the same slot; dismissing it leaves the progression note to show.
        if logReceipt != nil { return markSetsSeen() }
        guard let exercise = currentExercise else { return }
        acknowledgedProgressionNotes.insert(exercise.templateId)
        interactor.trackEvent(event: Event.progressionNoteAcknowledged)
    }

    /// A superset's card for `members`, with `current` the member the log button is on.
    func supersetCard(_ members: [WorkoutExerciseModel], current: String) -> SupersetCard {
        let timers = members.compactMap { restTimer(for: $0) }
        let letter = members.first?.supersetGroupId
            .flatMap { ActiveWorkout.supersetLetters(workoutSession.exercises)[$0] } ?? "A"
        let memberIds = members.map(\.id)
        var onDoLater: (@MainActor () -> Void)?
        if let first = members.first, canDoLater(first) {
            onDoLater = { [weak self] in self?.onDoLaterPressed(first.id) }
        }
        return SupersetCard(
            letter: letter,
            members: members,
            rows: ActiveWorkout.blockRows(members, letter: letter),
            nextSetId: ActiveWorkout.nextSetId(inBlock: members, current: current),
            showsColumnHeadings: ActiveWorkout.blockSharesColumns(members, units: units(for:)),
            restBefore: timers.contains { $0.anchor != .top } ? nil : timers.first,
            onAddRound: { [weak self] in self?.onAddRoundPressed(memberIds) },
            onDoLater: onDoLater,
            onRemoveSuperset: { [weak self] in self?.removeSuperset(memberIds) }
        )
    }

    /// The inline timer for `exercise`'s card, or `nil` when there is none to show. A rest still
    /// running counts down; one that has run out reads Ready until the next set is logged. Both
    /// times are the rest owner's, so a rest started from the Lock Screen, or running across a
    /// relaunch, draws the same as one started here.
    func restTimer(for exercise: WorkoutExerciseModel) -> InlineRestTimer? {
        let endsAt = interactor.restEndTime
        let startedAt = interactor.restStartedAt
        let rested = ActiveWorkout.latestCompletedSet(in: workoutSession.exercises)
        guard endsAt != nil || startedAt != nil,
              let anchor = ActiveWorkout.restAnchor(in: exercise, restedSet: rested, restStartedAt: startedAt)
        else { return nil }
        // A rest kept by an older build has no start: it began when its set was logged. With no
        // start at all, or one after the end, there is nothing to measure the bar against.
        guard let start = startedAt ?? rested?.completedAt, endsAt.map({ start < $0 }) ?? true else { return nil }
        return InlineRestTimer(anchor: anchor, startedAt: start, endsAt: endsAt)
    }
}

/// What the inline rest row draws.
struct InlineRestTimer: Equatable {
    let anchor: RestAnchor
    let startedAt: Date
    /// `nil` once the rest has run out.
    let endsAt: Date?
}
