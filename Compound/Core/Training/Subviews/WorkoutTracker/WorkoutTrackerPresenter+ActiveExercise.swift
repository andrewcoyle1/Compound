//
//  WorkoutTrackerPresenter+ActiveExercise.swift
//  Compound
//
//  The screen around one exercise at a time: the progress header, the current exercise's card,
//  the inline rest timer, the Up Next list and the log button at the foot. The rules are in
//  `ActiveWorkout`; this reads them against the live session.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    // MARK: - Current exercise

    /// The exercise on the card: the one opened, else the one the workout is up to.
    var currentExercise: WorkoutExerciseModel? {
        let exercises = workoutSession.exercises
        if let id = expandedExerciseId, let open = exercises.first(where: { $0.id == id }) { return open }
        return exercises.indices.contains(currentExerciseIndex) ? exercises[currentExerciseIndex] : exercises.last
    }

    /// Everything off the card with sets still to log, in workout order. A superset's partners
    /// are on the card with it.
    var upNextExercises: [WorkoutExerciseModel] {
        let onCard = ActiveWorkout.cardExerciseIds(current: currentExercise?.id, in: workoutSession.exercises)
        return workoutSession.exercises.filter { !onCard.contains($0.id) && !isComplete($0) }
    }

    /// Exercises already finished, kept reachable so a logged set can still be corrected.
    var completedExercises: [WorkoutExerciseModel] {
        let onCard = ActiveWorkout.cardExerciseIds(current: currentExercise?.id, in: workoutSession.exercises)
        return workoutSession.exercises.filter { !onCard.contains($0.id) && isComplete($0) }
    }

    func onExerciseSelected(_ exerciseId: String) {
        guard let index = workoutSession.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        expandedExerciseId = exerciseId
        currentExerciseIndex = index
        interactor.playHaptic(option: .selection)
        interactor.trackEvent(event: Event.exerciseSelected)
        refreshLiveActivity()
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
            expandedExerciseId = next.id
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

    /// Puts `group` at `index` among the other exercises, keeping the card where it was.
    private func move(_ group: [WorkoutExerciseModel], toIndex index: Int) {
        let ids = Set(group.map(\.id))
        var updated = workoutSession.exercises.filter { !ids.contains($0.id) }
        updated.insert(contentsOf: group, at: min(index, updated.count))
        let card = currentExercise?.id
        applyReorderedExercises(updated, movedFrom: nil, movedTo: index)
        if let card, let cardIndex = updated.firstIndex(where: { $0.id == card }) {
            expandedExerciseId = card
            currentExerciseIndex = cardIndex
        }
    }

    /// Shows Up Next's drag handles, or hides them again.
    func onReorderPressed() {
        editMode = editMode.isEditing ? .inactive : .active
        interactor.playHaptic(option: .selection)
    }

    /// Up Next shows only some of the exercises, so its positions are mapped back onto the
    /// workout's before moving.
    func moveUpNext(from source: IndexSet, to destination: Int) {
        let shown = upNextExercises.compactMap { exercise in workoutSession.exercises.firstIndex { $0.id == exercise.id } }
        let sourceIndices = IndexSet(source.compactMap { shown.indices.contains($0) ? shown[$0] : nil })
        let target = destination < shown.count ? shown[destination] : (shown.last.map { $0 + 1 } ?? workoutSession.exercises.count)
        moveExercises(from: sourceIndices, to: target)
    }

    // MARK: - Header

    var progress: ActiveWorkout.Progress {
        let index = currentExercise.flatMap { current in workoutSession.exercises.firstIndex { $0.id == current.id } }
        return ActiveWorkout.progress(of: workoutSession.exercises, currentIndex: index ?? currentExerciseIndex)
    }

    var workoutDateText: String {
        workoutSession.dateCreated.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    // MARK: - Exercise card

    func units(for exercise: WorkoutExerciseModel) -> ExerciseUnitPreference {
        interactor.getPreference(templateId: exercise.templateId)
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
            suggestion: progressionSuggestions[exercise.templateId],
            planned: exercise,
            last: previousExercises[exercise.templateId],
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

    func onProgressionNoteAcknowledged() {
        // The receipt sits in the same slot; dismissing it leaves the progression note to show.
        if logReceipt != nil { return markSetsSeen() }
        guard let exercise = currentExercise else { return }
        acknowledgedProgressionNotes.insert(exercise.templateId)
        interactor.trackEvent(event: Event.progressionNoteAcknowledged)
    }

    /// Today's top set for a finished exercise; the plan and last time's for one still to come.
    func upNextSummary(for exercise: WorkoutExerciseModel) -> String {
        let units = units(for: exercise)
        let showsBodyweight = bodyweightContribution(for: exercise) != nil
        if isComplete(exercise) {
            return ActiveWorkout.completedSummary(for: exercise, unit: units.weightUnit, distanceUnit: units.distanceUnit, showsBodyweight: showsBodyweight)
        }
        return ActiveWorkout.upNextSummary(
            for: exercise,
            last: previousExercises[exercise.templateId],
            unit: units.weightUnit,
            distanceUnit: units.distanceUnit,
            showsBodyweight: showsBodyweight
        )
    }

    // MARK: - Rest

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
        // A rest kept by an older build has no start: it began when its set was logged.
        return InlineRestTimer(anchor: anchor, startedAt: startedAt ?? rested?.completedAt, endsAt: endsAt)
    }

    /// Undoing the set a rest follows calls the rest off: there is nothing to rest from.
    func cancelRestIfUndone(comparedTo oldSession: WorkoutSessionModel) {
        guard restStartedAt != nil || interactor.restEndTime != nil,
              let rested = ActiveWorkout.latestCompletedSet(in: oldSession.exercises),
              workoutSession.exercises.contains(where: { $0.sets.contains { $0.id == rested.id && $0.completedAt == nil } })
        else { return }
        cancelRestTimer()
    }

    // MARK: - Footer

    /// When the running rest ends, while one runs: the footer offers Skip Rest instead of the next
    /// set. Cleared by the rest timer's owner the moment the rest runs out.
    var runningRestEnd: Date? {
        interactor.restEndTime.flatMap { $0 > Date() ? $0 : nil }
    }

    var primaryAction: ActiveWorkoutAction? {
        ActiveWorkout.primaryAction(exercises: workoutSession.exercises, currentExerciseId: currentExercise?.id)
    }

    /// Follows every keystroke in the current row, since the row edits the session directly.
    var primaryActionTitle: String {
        switch primaryAction {
        case let .logSet(exerciseId, setId)?:
            guard let exercise = workoutSession.exercises.first(where: { $0.id == exerciseId }),
                  let set = exercise.sets.first(where: { $0.id == setId }) else { return "" }
            let units = units(for: exercise)
            return ActiveWorkout.logTitle(
                for: set,
                in: exercise,
                unit: units.weightUnit,
                distanceUnit: units.distanceUnit,
                showsBodyweight: bodyweightContribution(for: exercise) != nil
            )
        case let .next(exerciseId)?:
            let name = workoutSession.exercises.first { $0.id == exerciseId }?.name ?? ""
            return String(localized: "Next: \(name)")
        case .finish?:
            return String(localized: "Finish Workout")
        case nil:
            return ""
        }
    }

    func onPrimaryActionPressed() {
        switch primaryAction {
        case let .logSet(exerciseId, setId)?:
            logSet(setId, in: exerciseId)
        case let .next(exerciseId)?:
            onExerciseSelected(exerciseId)
        case .finish?:
            // The notes sheet is the confirmation: the button became Finish under a tap meant
            // for the set before.
            onFinishPressed()
        case nil:
            break
        }
    }

    /// The one way a set is logged on this screen, from the log button, a row's Done or the set
    /// keyboard. The rule (`ActiveWorkout.log`, shared with the Live Activity) checks it, stamps it
    /// and says how long to rest — the rules, or a rest set by hand on the row; this plays the
    /// haptic, saves, starts the rest and lets smart progression re-suggest what is left.
    func logSet(_ setId: String, in exerciseId: String, customRestSeconds custom: Int? = nil, source: String = "log_button") {
        guard let exercise = workoutSession.exercises.first(where: { $0.id == exerciseId }) else { return }
        let settings = interactor.workoutSettings
        guard let outcome = ActiveWorkout.log(
            setId: setId,
            in: workoutSession,
            settings: settings,
            context: restContext(for: exercise),
            customRestSeconds: custom ?? customRestSeconds[setId],
            isAssisted: interactor.isAssisted(templateId: exercise.templateId)
        ) else { return }
        if let problem = outcome.problem {
            interactor.playHaptic(option: .error)
            router.showSimpleAlert(title: String(localized: "Unable to Log Set"), subtitle: problem)
            return
        }
        guard let set = outcome.session.exercises.first(where: { $0.id == exerciseId })?.sets.first(where: { $0.id == setId })
        else { return }

        interactor.playHaptic(option: .success)
        updateSet(set, in: exerciseId)
        persistFocus(currentExercise?.id)

        let rest = outcome.restSeconds
        interactor.trackEvent(event: SetTrackerRowPresenter.Event.setCompleted(
            setId: setId,
            exerciseId: exerciseId,
            useRestTimers: settings.useRestTimers,
            restDurationSeconds: rest ?? 0,
            onStartRestIsNil: false,
            source: source
        ))
        if settings.useRestTimers, let rest {
            startRestTimer(durationSeconds: rest)
        }
        applyLiveProgression(after: set, in: exerciseId)
    }

    func restContext(for exercise: WorkoutExerciseModel) -> RestDurationRules.ExerciseContext {
        RestDurationRules.ExerciseContext(
            restOverrideSeconds: interactor.exerciseRestOverride(for: exercise.templateId),
            exerciseTypeRawValue: interactor.allExercises.first { $0.id == exercise.templateId }?.type?.rawValue,
            planRestSeconds: exercise.restSeconds
        )
    }
}

/// What the inline rest row draws.
struct InlineRestTimer: Equatable {
    let anchor: RestAnchor
    /// `nil` only when nothing has been logged, and then there is no progress bar.
    let startedAt: Date?
    /// `nil` once the rest has run out.
    let endsAt: Date?
}
