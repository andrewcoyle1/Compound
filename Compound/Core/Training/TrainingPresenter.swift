//
//  TrainingPresenter.swift
//  Compound
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

    var activeMesocycle: Mesocycle? {
        interactor.activeMesocycle
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
    
    // MARK: - Add Menu

    func onNewMesocyclePressed() {
        router.showCreateMesocycleView(delegate: CreateMesocycleDelegate())
    }

    func onNewWorkoutPressed() {
        router.showCreateWorkoutView(delegate: CreateWorkoutDelegate())
    }

    func onNewExercisePressed() {
        router.showCreateExerciseView()
    }
    
    func onProfilePressed(transitionId: String, namespace: Namespace.ID) {
        router.showProfileViewZoom(transitionId: transitionId, namespace: namespace)
    }
    
    /// Finished workouts grouped by day in one pass, each in its mesocycle's colour and in the
    /// order they were done. Rest days are not workouts, so they leave the day blank. The calendar
    /// header used to ask for a count per visible day, and each answer filtered every session.
    func loggedWorkoutMarkersByDay() -> [Date: CalendarDayMarker] {
        let colours = Dictionary(interactor.mesocycles.map { ($0.id, $0.colour) }, uniquingKeysWith: { first, _ in first })
        let byDay = Dictionary(grouping: workoutSessions.filter { $0.endedAt != nil && !$0.isRestDay }) {
            calendar.startOfDay(for: $0.dateCreated)
        }
        return byDay.mapValues { sessions in
            .sessions(colours: sessions.sorted { $0.dateCreated < $1.dateCreated }.map { $0.mesocycleId.flatMap { colours[$0] } })
        }
    }
        
    func onStartEmptyWorkoutPressed() {
        startAfterActiveSessionCheck { [weak self] in
            try await self?.interactor.startBlankWorkout()
        }
    }

    /// With a workout already running, asks whether to resume it or replace it.
    private func startAfterActiveSessionCheck(_ start: @escaping @MainActor () async throws -> Void) {
        if activeSession != nil {
            router.showActiveWorkoutAlert(
                onResume: { [weak self] in
                    Task { @MainActor in self?.router.showWorkoutTrackerView() }
                },
                onReplace: { [weak self] in
                    Task { @MainActor in
                        do {
                            try self?.interactor.deleteActiveSession()
                        } catch {
                            self?.interactor.trackEvent(event: Event.deleteActiveSessionFail(error: error))
                        }
                        await self?.startThenShowTracker(start)
                    }
                }
            )
        } else {
            Task { await startThenShowTracker(start) }
        }
    }

    private func startThenShowTracker(_ start: @MainActor () async throws -> Void) async {
        interactor.trackEvent(event: Event.startWorkoutStart)
        do {
            try await start()
            interactor.trackEvent(event: Event.startWorkoutSuccess)
            router.showWorkoutTrackerView()
        } catch {
            interactor.trackEvent(event: Event.startWorkoutFail(error: error))
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
            session.endedAt != nil && !session.isRestDay && calendar.isDate(session.dateCreated, inSameDayAs: date)
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

    /// A choice among however many workouts the day holds, so an action sheet: an alert holds
    /// three buttons at most.
    private func showSessionPicker(sessions: [WorkoutSessionModel]) {
        router.showConfirmationDialog(
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
    
    func onMesocycleLibraryView() {
        router.showMesocycleLibraryView()
    }

    func onMacrocyclesPressed() {
        router.showMacrocyclesView()
    }

    func onNewMacrocyclePressed() {
        router.showMacrocycleDetailView(delegate: MacrocycleDetailDelegate())
    }
    
    func onChooseMesocyclePressed() {
        router.showMesocycleLibraryView()
    }
    
    func onWorkoutLibraryPressed() {
        router.showWorkoutsView(delegate: WorkoutsDelegate())
    }
    
    func onWorkoutHistoryPressed() {
        router.showWorkoutHistoryView()
    }

    func onExerciseLibraryPressed() {
        router.showExercisesView()
    }

    // MARK: - Search

    /// Training's search field: exercises and workouts. Mesocycles are few enough to browse.
    var searchString: String = ""

    var isSearching: Bool {
        SearchMatch.isSearching(searchString)
    }

    var filteredExercises: [ExerciseModel] {
        interactor.allExercises
            .filter { SearchMatch.matches(searchString, [$0.name, $0.description] + $0.muscleGroups.keys.map(\.rawValue) + $0.alternateNames) }
            .sortedByKeyPath(keyPath: \.name, ascending: true)
    }

    var filteredWorkoutTemplates: [WorkoutTemplateModel] {
        interactor.allWorkoutTemplates
            .filter { SearchMatch.matches(searchString, [$0.name, $0.description] + $0.exercises.map(\.exercise.name)) }
            .sortedByKeyPath(keyPath: \.name, ascending: true)
    }

    var hasSearchResults: Bool {
        !filteredExercises.isEmpty || !filteredWorkoutTemplates.isEmpty
    }

    func onExerciseResultPressed(_ exercise: ExerciseModel) {
        router.showExerciseDetailView(templateId: exercise.id, name: exercise.name, delegate: ExerciseDetailDelegate(), themeColor: nil)
    }

    func onWorkoutResultPressed(_ workout: WorkoutTemplateModel) {
        router.showWorkoutTemplateDetailView(
            delegate: WorkoutTemplateDetailDelegate(
                workoutTemplate: workout,
                mesocycleId: nil,
                onStartWorkoutPressed: { [weak self] in
                    Task { @MainActor in self?.router.showWorkoutTrackerView() }
                }
            )
        )
    }

    /// The row's Start button: the workout starts here rather than after its detail screen.
    func onStartWorkoutResultPressed(_ workout: WorkoutTemplateModel) {
        startAfterActiveSessionCheck { [weak self] in
            try await self?.interactor.startWorkout(for: workout, in: nil)
        }
    }
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
        case startWorkoutStart
        case startWorkoutSuccess
        case startWorkoutFail(error: Error)
        case deleteActiveSessionFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:                      return "TrainingView_Appear"
            case .onDisappear:                   return "TrainingView_Disappear"
            case .openCompletedSessionStart:     return "TrainingView_OpenCompletedSession_Start"
            case .openCompletedSessionSuccess:   return "TrainingView_OpenCompletedSession_Success"
            case .openCompletedSessionFail:      return "TrainingView_OpenCompletedSession_Fail"
            case .startWorkoutStart:             return "TrainingView_StartWorkout_Start"
            case .startWorkoutSuccess:           return "TrainingView_StartWorkout_Success"
            case .startWorkoutFail:              return "TrainingView_StartWorkout_Fail"
            case .deleteActiveSessionFail:       return "TrainingView_DeleteActiveSession_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .openCompletedSessionFail(error: let error), .startWorkoutFail(error: let error), .deleteActiveSessionFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .openCompletedSessionFail, .startWorkoutFail:
                return .severe
            case .deleteActiveSessionFail:
                return .warning
            default:
                return .analytic
            }
        }
    }
}
