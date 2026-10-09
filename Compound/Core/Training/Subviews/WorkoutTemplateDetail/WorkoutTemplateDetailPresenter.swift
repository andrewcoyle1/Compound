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

    func onViewAppear(delegate: WorkoutTemplateDetailDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: WorkoutTemplateDetailDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
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
        interactor.trackEvent(event: Event.deleteWorkoutStart)
        do {
            // Delete the workout template
            try await interactor.deleteWorkoutTemplate(id: template.id)
            interactor.trackEvent(event: Event.deleteWorkoutSuccess)

            // Dismiss the view after successful deletion
            onDismiss()
        } catch {
            interactor.trackEvent(event: Event.deleteWorkoutFail(error: error))
            isDeleting = false
            router.showSimpleAlert(title: String(localized: "Unable to Delete Workout"), subtitle: String(localized: "Please try again."))
        }
    }

    func onStartWorkoutPressed(
        onStartWorkout: (@Sendable () -> Void)?,
        workoutTemplate: WorkoutTemplateModel,
        mesocycleId: String?,
        microcycleIndex: Int? = nil,
        isDeloadCycle: Bool = false
    ) {
        let shouldProceed = checkForActiveWorkout(
            onResumeWorkout: { [weak self] in
                Task { @MainActor in
                    self?.resumeActiveWorkout()
                }
            },
            onStartNewWorkout: { [weak self] in
                Task { @MainActor in
                    self?.performStartWorkout(
                        onStartWorkout: onStartWorkout,
                        workoutTemplate: workoutTemplate,
                        mesocycleId: mesocycleId,
                        microcycleIndex: microcycleIndex,
                        isDeloadCycle: isDeloadCycle
                    )
                }
            }
        )

        if shouldProceed {
            performStartWorkout(
                onStartWorkout: onStartWorkout,
                workoutTemplate: workoutTemplate,
                mesocycleId: mesocycleId,
                microcycleIndex: microcycleIndex,
                isDeloadCycle: isDeloadCycle
            )
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
                    do {
                        try self?.interactor.deleteActiveSession()
                    } catch {
                        self?.interactor.trackEvent(event: Event.deleteActiveSessionFail(error: error))
                    }
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
    
    private func performStartWorkout(
        onStartWorkout: (() -> Void)?,
        workoutTemplate: WorkoutTemplateModel,
        mesocycleId: String?,
        microcycleIndex: Int?,
        isDeloadCycle: Bool
    ) {
        guard !isStarting else { return }
        isStarting = true
        interactor.trackEvent(event: Event.startWorkoutStart(templateId: workoutTemplate.id))
        Task {
            defer { isStarting = false }
            do {
                try await self.interactor.startWorkout(
                    for: workoutTemplate,
                    in: mesocycleId,
                    microcycleIndex: microcycleIndex,
                    isDeloadCycle: isDeloadCycle
                )
                self.interactor.trackEvent(event: Event.startWorkoutSuccess(templateId: workoutTemplate.id))
                self.router.dismissEnvironment()
                self.router.dismissScreen()
                onStartWorkout?()
            } catch {
                self.interactor.trackEvent(event: Event.startWorkoutFail(error: error))
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

    // MARK: - The plan

    /// "Week 3 · 3 sets · 8–10 · RIR 1" for the week the screen was opened on, or the base
    /// targets for a template on its own.
    func weekSummary(for exercise: WorkoutTemplateExercise, delegate: WorkoutTemplateDetailDelegate) -> String {
        exercise.weekSummary(microcycle: delegate.microcycleIndex)
    }

    /// The exercise with that week's targets in place of its base ones, for the row to draw.
    func exerciseForWeek(_ exercise: WorkoutTemplateExercise, delegate: WorkoutTemplateDetailDelegate) -> WorkoutTemplateExercise {
        var week = exercise
        week.setTargets = exercise.setTargets(forMicrocycle: delegate.microcycleIndex)
        return week
    }

    func alternativeNames(for exercise: WorkoutTemplateExercise) -> [String] {
        exercise.alternativeNames(in: interactor.allExercises)
    }

    /// "Superset A", "Superset B" by group id, lettered in the order the groups first appear.
    func supersetLabels(in exercises: [WorkoutTemplateExercise]) -> [String: String] {
        WorkoutTemplateExercise.supersetLetters(in: exercises).mapValues { "\(String(localized: "Superset")) \($0)" }
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

    /// The user's own mesocycle this workout is a day of, nil for a library template. Edit
    /// Workout on a day used to save it to the library, which made the copy that drifted.
    func owningMesocycle(delegate: WorkoutTemplateDetailDelegate) -> Mesocycle? {
        guard let userId = currentUser?.userId,
              let id = delegate.mesocycle?.id ?? delegate.mesocycleId else { return nil }
        return interactor.mesocycles.first { $0.id == id && $0.authorId == userId }
    }

    func onEditMesocyclePressed(_ mesocycle: Mesocycle) {
        router.showEditMesocycleView(delegate: EditMesocycleDelegate(mesocycle: mesocycle))
    }

    /// A library workout of its own, with a new id, that no longer follows the mesocycle. Named
    /// apart from a library workout it would otherwise share a name with.
    func onSaveCopyPressed(template: WorkoutTemplateModel) {
        guard let userId = currentUser?.userId else { return }
        let clashes = interactor.allWorkoutTemplates.contains { $0.name.caseInsensitiveCompare(template.name) == .orderedSame }
        let copy = WorkoutTemplateModel(
            authorId: userId,
            name: clashes ? String(localized: "\(template.name) (copy)") : template.name,
            description: template.description,
            gymProfileId: template.gymProfileId,
            exercises: template.exercises
        )
        interactor.trackEvent(event: Event.saveCopyStart)
        Task {
            do {
                try await interactor.saveWorkoutTemplate(workoutTemplate: copy, image: nil)
                interactor.trackEvent(event: Event.saveCopySuccess)
                interactor.playHaptic(option: .success)
                interactor.showAppToast(AppToast(style: .success, message: String(localized: "Saved \(copy.name) to your workouts")))
            } catch {
                interactor.trackEvent(event: Event.saveCopyFail(error: error))
                interactor.playHaptic(option: .error)
                router.showAlert(title: String(localized: "Unable to Save Workout"), error: error)
            }
        }
    }
}

extension WorkoutTemplateDetailPresenter {
    enum Event: LoggableEvent {
        case onAppear(delegate: WorkoutTemplateDetailDelegate)
        case onDisappear(delegate: WorkoutTemplateDetailDelegate)
        case deleteWorkoutStart
        case deleteWorkoutSuccess
        case deleteWorkoutFail(error: Error)
        case startWorkoutStart(templateId: String)
        case startWorkoutSuccess(templateId: String)
        case startWorkoutFail(error: Error)
        case deleteActiveSessionFail(error: Error)
        case saveCopyStart
        case saveCopySuccess
        case saveCopyFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:                return "WorkoutTemplateDetailView_Appear"
            case .onDisappear:             return "WorkoutTemplateDetailView_Disappear"
            case .deleteWorkoutStart:      return "WorkoutTemplateDetailView_DeleteWorkout_Start"
            case .deleteWorkoutSuccess:    return "WorkoutTemplateDetailView_DeleteWorkout_Success"
            case .deleteWorkoutFail:       return "WorkoutTemplateDetailView_DeleteWorkout_Fail"
            case .startWorkoutStart:       return "WorkoutTemplateDetailView_StartWorkout_Start"
            case .startWorkoutSuccess:     return "WorkoutTemplateDetailView_StartWorkout_Success"
            case .startWorkoutFail:        return "WorkoutTemplateDetailView_StartWorkout_Fail"
            case .deleteActiveSessionFail: return "WorkoutTemplateDetailView_DeleteActiveSession_Fail"
            case .saveCopyStart:           return "WorkoutTemplateDetailView_SaveCopy_Start"
            case .saveCopySuccess:         return "WorkoutTemplateDetailView_SaveCopy_Success"
            case .saveCopyFail:            return "WorkoutTemplateDetailView_SaveCopy_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let delegate), .onDisappear(let delegate):
                return ["workout_id": delegate.workoutTemplate.id, "allows_start": delegate.allowsStart]
            case .startWorkoutStart(let templateId), .startWorkoutSuccess(let templateId):
                return ["workout_id": templateId]
            case .deleteWorkoutFail(let error), .startWorkoutFail(let error), .deleteActiveSessionFail(let error), .saveCopyFail(let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .deleteWorkoutFail, .startWorkoutFail, .saveCopyFail: return .severe
            case .deleteActiveSessionFail:              return .warning
            default:                                    return .analytic
            }
        }
    }
}
