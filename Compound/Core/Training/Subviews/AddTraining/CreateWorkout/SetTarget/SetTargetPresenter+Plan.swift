//
//  SetTargetPresenter+Plan.swift
//  Compound
//
//  The template exercise's plan in the set-target editor: warm-ups, rest, notes, link,
//  substitutions and how the targets vary by week. Every edit lands in the working copy, so the
//  editor's own Save and Cancel decide whether it is kept.
//

import SwiftUI

extension SetTargetPresenter {

    // MARK: - Warm-ups

    var warmupSetChoices: [Int?] {
        SetTargetPlan.choices(SetTargetPlan.warmupSetChoices, including: workingExercise.warmupSetCount)
    }

    /// Nil is automatic: the weight-based rule.
    var warmupSetCount: Int? {
        get { workingExercise.warmupSetCount }
        set { workingExercise.warmupSetCount = newValue }
    }

    func warmupSetTitle(_ count: Int?) -> String {
        count.map { $0.formatted() } ?? String(localized: "Automatic")
    }

    // MARK: - Rest

    var restSecondsChoices: [Int?] {
        SetTargetPlan.choices(SetTargetPlan.restSecondsChoices, including: workingExercise.restSeconds)
    }

    /// Nil is automatic: the exercise and global rest settings.
    var restSeconds: Int? {
        get { workingExercise.restSeconds }
        set { workingExercise.restSeconds = newValue }
    }

    func restTitle(_ seconds: Int?) -> String {
        seconds.map { Format.duration(TimeInterval($0)) } ?? String(localized: "Automatic")
    }

    // MARK: - Notes

    /// Trimmed on save; an empty note is none.
    var notes: String {
        get { workingExercise.notes ?? "" }
        set { workingExercise.notes = newValue.isEmpty ? nil : newValue }
    }

    // MARK: - Link

    /// Empty, or a web address.
    var linkIsValid: Bool {
        linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || SetTargetPlan.validatedLink(linkText) != nil
    }

    func onLinkTextChanged() {
        guard linkIsValid else { return }
        workingExercise.linkURL = SetTargetPlan.validatedLink(linkText)
        showsLinkError = false
    }

    func onLinkSubmitted() {
        showsLinkError = !linkIsValid
    }

    // MARK: - Substitutions

    /// The planned alternatives the library knows, in the plan's order.
    var substitutes: [ExerciseModel] {
        let library = interactor.allExercises
        return workingExercise.substituteExerciseIds.compactMap { id in library.first { $0.id == id } }
    }

    /// The picker shows the substitutions already chosen as ticked, adds what is ticked there, and
    /// cannot pick the exercise itself.
    func onAddSubstitutionPressed() {
        let picked = Binding<[WorkoutTemplateExercise]>(
            get: { [weak self] in
                self?.substitutes.map { WorkoutTemplateExercise(exercise: $0, setRestTimers: false) } ?? []
            },
            set: { [weak self] newValue in
                self?.addSubstitutions(newValue.map(\.exercise.id))
            }
        )
        router.showExercisesPickerView(delegate: ExercisesPickerDelegate(
            addedExercises: picked,
            excludedExerciseIds: [workingExercise.exercise.id]
        ))
    }

    /// Adds the ids not already listed, never the exercise itself.
    func addSubstitutions(_ ids: [String]) {
        for id in ids where id != workingExercise.exercise.id && !workingExercise.substituteExerciseIds.contains(id) {
            workingExercise.substituteExerciseIds.append(id)
        }
    }

    func onRemoveSubstitutionPressed(_ exercise: ExerciseModel) {
        workingExercise.substituteExerciseIds.removeAll { $0 == exercise.id }
    }

    // MARK: - Weekly variation

    /// "Week 1: 2 sets · From week 2: 3 sets", or that nothing varies.
    var variationSummary: String {
        SetTargetPlan.variationSummary(base: workingExercise.setTargets, overrides: workingExercise.setTargetsByMicrocycle)
            ?? String(localized: "Same every week")
    }

    func onVariesByWeekPressed() {
        router.showMicrocycleVariationsView(delegate: MicrocycleVariationsDelegate(exercise: workingExercise) { [weak self] overrides in
            self?.workingExercise.setTargetsByMicrocycle = overrides
        })
    }
}
