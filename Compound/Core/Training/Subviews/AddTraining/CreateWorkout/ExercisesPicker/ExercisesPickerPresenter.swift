//
//  ExercisesPickerPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

@Observable
@MainActor
class ExercisesPickerPresenter {
    private let interactor: ExercisesPickerInteractor
    private let router: ExercisesPickerRouter

    private let committedExercises: Binding<[WorkoutTemplateExercise]>
    private(set) var workingExercises: [WorkoutTemplateExercise] = []
    
    init(
        interactor: ExercisesPickerInteractor,
        router: ExercisesPickerRouter,
        delegate: ExercisesPickerDelegate
    ) {
        self.interactor = interactor
        self.router = router
        self.committedExercises = delegate.addedExercises
    }

    /// Ticked exercises are lost if the sheet closes, so the swipe is blocked and close asks.
    var hasUnsavedChanges: Bool {
        !workingExercises.isEmpty
    }

    /// Confirming with nothing new ticked would add nothing.
    var canSave: Bool {
        !workingExercises.isEmpty
    }

    /// Exercises already in the workout show as ticked, beside the ones picked here.
    var selectedExercises: [ExerciseModel] {
        committedExercises.wrappedValue.map(\.exercise) + workingExercises.map(\.exercise)
    }

    func onDismissPressed() {
        guard hasUnsavedChanges else {
            router.dismissScreen()
            return
        }
        router.showDiscardChangesDialog { [weak self] in
            Task { @MainActor in self?.router.dismissScreen() }
        }
    }

    /// Reopening the picker started from an empty selection, so an exercise already in the
    /// workout could be added a second time.
    func onSavePressed() {
        guard canSave else { return }
        let existing = Set(committedExercises.wrappedValue.map(\.exercise.id))
        committedExercises.wrappedValue.append(contentsOf: workingExercises.filter { !existing.contains($0.exercise.id) })
        router.dismissScreen()
    }

    /// An exercise already in the workout stays ticked: it used to count as picked and then add
    /// nothing.
    func onExercisePressed(exercise: ExerciseModel) {
        guard !committedExercises.wrappedValue.contains(where: { $0.exercise.id == exercise.id }) else { return }
        if let index = workingExercises.firstIndex(where: { $0.exercise.id == exercise.id }) {
            workingExercises.remove(at: index)
        } else {
            let workoutExercise = WorkoutTemplateExercise(exercise: exercise, setRestTimers: false)
            workingExercises.append(workoutExercise)
        }
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear:     return "ExercisesPickerView_Appear"
            case .onDisappear:  return "ExercisesPickerView_Disappear"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }
}
