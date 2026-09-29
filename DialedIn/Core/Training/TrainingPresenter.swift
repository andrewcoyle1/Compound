//
//  TrainingPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

struct MicrocycleWorkoutTemplateModelItem: Identifiable {
    let id: String
    let date: Date
    let dayPlan: WorkoutTemplateModel
    let completedSessionId: String?

    var isCompleted: Bool {
        completedSessionId != nil
    }
}

struct MicrocycleCycleState {
    let cycleIndex: Int
    let cyclesTotal: Int
    let completedInCurrentCycle: Set<String>
}

@Observable
@MainActor
class TrainingPresenter {
    
    let interactor: TrainingInteractor
    let router: TrainingRouter
    
    let calendar = Calendar.current
    
    var currentUser: UserModel? {
        interactor.currentUser
    }
    
    var userImageUrl: String? {
        interactor.userImageUrl
    }

    var activeSession: WorkoutSessionModel? {
        interactor.activeSession
    }

    var workoutSessions: [WorkoutSessionModel] {
        interactor.workoutSessions
    }

    var activeTrainingProgram: TrainingProgram? {
        interactor.activeTrainingProgram
    }
    
    var favouriteGymProfile: GymProfileModel? {
        interactor.favouriteGymProfile
    }
    
    init(
        interactor: TrainingInteractor,
        router: TrainingRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: TrainingDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: TrainingDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onAddPressed() {
        let delegate = AddTrainingDelegate(
            onSelectProgram: { [weak self] in
                self?.router.showCreateProgramView(delegate: CreateProgramDelegate())
            },
            onSelectWorkout: { [weak self] in
                self?.router.showCreateWorkoutView(delegate: CreateWorkoutDelegate())
            },
            onSelectExercise: { [weak self] in
                self?.router.showCreateExerciseView()
            }
        )
        router.showAddTrainingView(delegate: delegate, onDismiss: nil)
    }
    
    func onProfilePressed(transitionId: String, namespace: Namespace.ID) {
        router.showProfileViewZoom(transitionId: transitionId, namespace: namespace)
    }
    
    /// Logged sessions grouped by day in one pass. The calendar header used to ask for a count
    /// per visible day, and each answer filtered every session with `isDate(_:inSameDayAs:)`.
    func loggedWorkoutMarkersByDay() -> [Date: CalendarDayMarker] {
        let now = Date()
        let counts = workoutSessions.reduce(into: [Date: Int]()) { counts, session in
            guard session.endedAt != nil else { return }
            if session.isRestDay && session.dateCreated > now { return }
            counts[calendar.startOfDay(for: session.dateCreated), default: 0] += 1
        }
        return counts.mapValues { .count($0) }
    }
        
    func onStartEmptyWorkoutPressed() {
        if activeSession != nil {
            router.showActiveWorkoutAlert(
                onResume: { [weak self] in
                    Task { @MainActor in self?.router.showWorkoutTrackerView() }
                },
                onReplace: { [weak self] in
                    Task { @MainActor in
                        try? self?.interactor.deleteActiveSession()
                        await self?.startBlankWorkout()
                    }
                }
            )
        } else {
            Task { await startBlankWorkout() }
        }
    }

    private func startBlankWorkout() async {
        do {
            try await interactor.startBlankWorkout()
            router.showWorkoutTrackerView()
        } catch {
            router.showSimpleAlert(title: String(localized: "Could Not Start Workout"), subtitle: String(localized: "Please try again."))
        }
    }
    
    func onDatePressed(date: Date) {
        let sessions = sessionsForDate(date)
        switch sessions.count {
        case 0:
            break
        case 1:
            // Safe: this arm runs only when there is exactly one session.
            openCompletedSession(sessionId: sessions[0].id)
        default:
            showSessionPicker(sessions: sessions)
        }
    }
    
    private func sessionsForDate(_ date: Date) -> [WorkoutSessionModel] {
        interactor.workoutSessions.filter { session in
            guard session.endedAt != nil,
                  calendar.isDate(session.dateCreated, inSameDayAs: date) else { return false }
            if session.isRestDay { return session.dateCreated <= Date() }
            return true
        }
    }
        
    private func resumeActiveWorkout() {
        guard activeSession != nil else { return }
        router.showWorkoutTrackerView()
    }
    
    private func openCompletedSession(sessionId: String) {
        interactor.trackEvent(event: Event.openCompletedSessionStart)
        guard let session = workoutSessions.first(where: { $0.id == sessionId }) else {
            // The id came from a session this screen was holding a moment ago, so losing it means
            // the sync engine dropped it mid-tap. Returning silently left a Start with no terminal
            // event: the tap looked like a screen nobody opened.
            interactor.trackEvent(event: Event.openCompletedSessionFail(error: TrainingError.sessionNotFound))
            return
        }
        router.showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate(workoutSession: session))
        interactor.trackEvent(event: Event.openCompletedSessionSuccess)
    }

    private func showSessionPicker(sessions: [WorkoutSessionModel]) {
        router.showAlert(
            title: String(localized: "Multiple Workouts"),
            subtitle: String(localized: "Which workout would you like to open?"),
            buttons: {
                AnyView(
                    VStack {
                        ForEach(sessions) { session in
                            let time = session.dateCreated.formatted(date: .omitted, time: .shortened)
                            Button("\(session.name) · \(time)") {
                                self.openCompletedSession(sessionId: session.id)
                            }
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }
        
    // MARK: - Library Navigation
    
    func onTrainingProgramLibraryView() {
        router.showTrainingProgramLibraryView()
    }
    
    func onChooseProgramPressed() {
        router.showTrainingProgramLibraryView()
    }
    
    func onWorkoutLibraryPressed() {
        router.showWorkoutsView(delegate: WorkoutsDelegate())
    }
    
    func onWorkoutHistoryPressed() {
        router.showWorkoutHistoryView()
    }
    
    #if DEV || MOCK
    func onDevSettingsPressed() {
        router.showDevSettingsView()
    }
    #endif
}

enum TrainingError: LocalizedError {
    case sessionNotFound

    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return String(localized: "The workout session is no longer available")
        }
    }
}

extension TrainingPresenter {
    enum Event: LoggableEvent {
        case onAppear(delegate: TrainingDelegate)
        case onDisappear(delegate: TrainingDelegate)
        case openCompletedSessionStart
        case openCompletedSessionSuccess
        case openCompletedSessionFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:                      return "TrainingView_Appear"
            case .onDisappear:                   return "TrainingView_Disappear"
            case .openCompletedSessionStart:     return "TrainingView_OpenCompletedSession_Start"
            case .openCompletedSessionSuccess:   return "TrainingView_OpenCompletedSession_Success"
            case .openCompletedSessionFail:      return "TrainingView_OpenCompletedSession_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .openCompletedSessionFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .openCompletedSessionFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
