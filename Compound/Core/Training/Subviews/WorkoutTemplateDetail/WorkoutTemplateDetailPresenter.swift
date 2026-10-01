//
//  WorkoutTemplateDetailPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

@Observable
@MainActor
class WorkoutTemplateDetailPresenter {
    private let interactor: WorkoutTemplateDetailInteractor
    private let router: WorkoutTemplateDetailRouter

    private(set) var isDeleting: Bool = false
    /// Start Workout had no guard, so a second tap during the start ran it twice.
    private(set) var isStarting: Bool = false

    var isBookmarked: Bool = false
    var isFavourited: Bool = false
        
    var currentUser: UserModel? {
        interactor.currentUser
    }
    
    var activeSession: WorkoutSessionModel? {
        interactor.activeSession
    }
    
    init(
        interactor: WorkoutTemplateDetailInteractor,
        router: WorkoutTemplateDetailRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func showDeleteConfirmation(workoutTemplate: WorkoutTemplateModel) {
        router.showAlert(title: String(localized: "Delete Workout"), subtitle: String(localized: "Are you sure you want to delete '\(workoutTemplate.name)'? This action cannot be undone."), buttons: {
            AnyView(
                HStack {
                    Button("Delete", role: .destructive) {
                        Task {
                            await self.deleteWorkout(template: workoutTemplate, onDismiss: {
                                self.router.dismissScreen()
                            })
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            )
        })
    }

    func targetMuscleSummaries(exercises: [WorkoutTemplateExercise]) -> [TargetMuscleSummary] {
        MuscleVolume.targetSummaries(exercises: exercises)
    }

    func deleteWorkout(template: WorkoutTemplateModel, onDismiss: @escaping () -> Void) async {
        isDeleting = true
        do {
            // Delete the workout template
            try await interactor.deleteWorkoutTemplate(id: template.id)
            
            // Dismiss the view after successful deletion
            onDismiss()
        } catch {
            isDeleting = false
            router.showSimpleAlert(title: String(localized: "Unable to Delete Workout"), subtitle: String(localized: "Please try again."))
        }
    }

    func onStartWorkoutPressed(onStartWorkout: (@Sendable () -> Void)?, workoutTemplate: WorkoutTemplateModel, mesocycleId: String?, isDeloadCycle: Bool = false) {
        let shouldProceed = checkForActiveWorkout(
            onResumeWorkout: { [weak self] in
                Task { @MainActor in
                    self?.resumeActiveWorkout()
                }
            },
            onStartNewWorkout: { [weak self] in
                Task { @MainActor in
                    self?.performStartWorkout(onStartWorkout: onStartWorkout, workoutTemplate: workoutTemplate, mesocycleId: mesocycleId, isDeloadCycle: isDeloadCycle)
                }
            }
        )

        if shouldProceed {
            performStartWorkout(onStartWorkout: onStartWorkout, workoutTemplate: workoutTemplate, mesocycleId: mesocycleId, isDeloadCycle: isDeloadCycle)
        }
    }
    
    // MARK: - Active Workout Safeguard
    
    /// The shared prompt, so both start buttons ask the same question with the same answers.
    private func checkForActiveWorkout(onResumeWorkout: @escaping @Sendable () -> Void, onStartNewWorkout: @escaping @Sendable () -> Void) -> Bool {
        guard activeSession != nil else {
            return true
        }

        router.showActiveWorkoutAlert(
            onResume: onResumeWorkout,
            onReplace: { [weak self] in
                Task { @MainActor in
                    try? self?.interactor.deleteActiveSession()
                    onStartNewWorkout()
                }
            }
        )

        return false
    }
    
    private func resumeActiveWorkout() {
        guard activeSession != nil else { return }
        router.dismissEnvironment()
        router.showWorkoutTrackerView()
    }
    
    private func performStartWorkout(onStartWorkout: (() -> Void)?, workoutTemplate: WorkoutTemplateModel, mesocycleId: String?, isDeloadCycle: Bool = false) {
        guard !isStarting else { return }
        isStarting = true
        Task {
            defer { isStarting = false }
            do {
                try await self.interactor.startWorkout(for: workoutTemplate, in: mesocycleId)
                if isDeloadCycle, var session = self.activeSession {
                    session.applyDeloadWeightReduction()
                    try? self.interactor.updateActiveSession(session)
                }
                self.router.dismissEnvironment()
                self.router.dismissScreen()
                onStartWorkout?()
            } catch {
                self.router.showSimpleAlert(title: String(localized: "Unable to Start Workout"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    /// The call behind every exercise row was commented out, so the rows highlighted on press and
    /// then did nothing. Opens the exercise's own detail — history, charts and records.
    func onExercisePressed(_ exercise: ExerciseModel) {
        interactor.trackEvent(eventName: "WorkoutTemplateDetailView_Exercise_Press", parameters: ["exercise_id": exercise.id], type: .analytic)
        router.showExerciseModelDetailView(delegate: ExerciseModelDetailDelegate(exerciseModel: exercise))
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    func onEditWorkoutPressed(template: WorkoutTemplateModel) {
        router.showCreateWorkoutView(delegate: CreateWorkoutDelegate(workoutTemplate: template))
    }

    func onSharePressed(template: WorkoutTemplateModel) {
        router.showShareToFollowerView(delegate: ShareToFollowerDelegate(payload: .template(template)))
    }
}
