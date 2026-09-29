//
//  WorkoutTemplateDetailPresenter.swift
//  DialedIn
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
    
    func formattedSetCount(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(rounded - value) < 0.000_01 {
            return "\(Int(rounded))"
        } else {
            return String(format: "%.1f", value)
        }
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
            router.showSimpleAlert(title: String(localized: "Failed to delete workout"), subtitle: String(localized: "Please try again later"))
        }
    }

    func onStartWorkoutPressed(onStartWorkout: (@Sendable () -> Void)?, workoutTemplate: WorkoutTemplateModel, trainingProgramId: String?, isDeloadCycle: Bool = false) {
        let shouldProceed = checkForActiveWorkout(
            onResumeWorkout: { [weak self] in
                Task { @MainActor in
                    self?.resumeActiveWorkout()
                }
            },
            onStartNewWorkout: { [weak self] in
                Task { @MainActor in
                    self?.performStartWorkout(onStartWorkout: onStartWorkout, workoutTemplate: workoutTemplate, trainingProgramId: trainingProgramId, isDeloadCycle: isDeloadCycle)
                }
            }
        )

        if shouldProceed {
            performStartWorkout(onStartWorkout: onStartWorkout, workoutTemplate: workoutTemplate, trainingProgramId: trainingProgramId, isDeloadCycle: isDeloadCycle)
        }
    }
    
    // MARK: - Active Workout Safeguard
    
    private func checkForActiveWorkout(onResumeWorkout: @escaping @Sendable () -> Void, onStartNewWorkout: @escaping @Sendable () -> Void) -> Bool {
        guard let activeSession = activeSession else {
            return true
        }
        
        router.showAlert(
            title: String(localized: "Workout In Progress"),
            subtitle: String(localized: "You already have '\(activeSession.name)' in progress. What would you like to do?"),
            buttons: {
                AnyView(
                    VStack {
                        Button("Resume Current Workout") {
                            onResumeWorkout()
                        }
                        Button("Discard & Start New", role: .destructive) {
                            try? self.interactor.deleteActiveSession()
                            onStartNewWorkout()
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
        
        return false
    }
    
    private func resumeActiveWorkout() {
        guard activeSession != nil else { return }
        router.dismissEnvironment()
        router.showWorkoutTrackerView()
    }
    
    private func performStartWorkout(onStartWorkout: (() -> Void)?, workoutTemplate: WorkoutTemplateModel, trainingProgramId: String?, isDeloadCycle: Bool = false) {
        Task {
            do {
                try await self.interactor.startWorkout(for: workoutTemplate, in: trainingProgramId)
                if isDeloadCycle, var session = self.activeSession {
                    session.applyDeloadWeightReduction()
                    try? self.interactor.updateActiveSession(session)
                }
                self.router.dismissEnvironment()
                self.router.dismissScreen()
                onStartWorkout?()
            } catch {
                self.router.showSimpleAlert(title: String(localized: "Unable to start workout"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    #if DEV || MOCK
    func onDevSettingsPressed() {
        router.showDevSettingsView()
    }
    #endif

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
