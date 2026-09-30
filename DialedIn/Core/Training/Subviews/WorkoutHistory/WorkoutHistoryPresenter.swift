//
//  WorkoutHistoryPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 20/10/2025.
//

import SwiftUI

@Observable
@MainActor
class WorkoutHistoryPresenter {
    private let interactor: WorkoutHistoryInteractor
    private let router: WorkoutHistoryRouter

    private(set) var isLoading = false
    
    var currentUser: UserModel? {
        interactor.currentUser
    }
    
    var selectedSession: WorkoutSessionModel?

    /// The list is headed "Completed Workouts", so only finished ones belong in it.
    ///
    /// `interactor.workoutSessions` is everything the sync engine holds, which includes the
    /// workout currently in progress (started sessions are saved straight away, with no
    /// `endedAt`) and the rest days the program pre-creates for days that have not arrived yet.
    /// Both were being listed and counted as history.
    var workoutSessions: [WorkoutSessionModel] {
        let now = Date()
        return interactor.workoutSessions
            .filter { session in
                guard session.endedAt != nil else { return false }
                if session.isRestDay { return session.dateCreated <= now }
                return true
            }
            .sorted { ($0.dateCreated) > ($1.dateCreated) }
    }
    
    init(
        interactor: WorkoutHistoryInteractor,
        router: WorkoutHistoryRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onWorkoutSessionPressed(session: WorkoutSessionModel, layoutMode: LayoutMode) {
        selectedSession = session
        router.showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate(workoutSession: session))
    }

    /// Manual retry from the empty state. Sessions arrive through a live sync engine, so this
    /// re-runs the remote sync rather than doing a one-off read; `isLoading` and the
    /// `syncSessions*` events were already declared here for it but never wired up.
    func onReloadPressed() {
        guard !isLoading else { return }

        interactor.trackEvent(event: Event.syncSessionsStart)
        isLoading = true

        Task {
            await interactor.syncAllRemoteDataIfLoggedIn()
            isLoading = false
            interactor.trackEvent(event: Event.syncSessionsSuccess)
        }
    }
    
}

extension WorkoutHistoryPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case syncSessionsStart
        case syncSessionsSuccess

        var eventName: String {
            switch self {
            case .onAppear:             return "WorkoutHistoryView_Appear"
            case .onDisappear:          return "WorkoutHistoryView_Disappear"
            case .syncSessionsStart:    return "WorkoutHistoryView_SyncSessions_Start"
            case .syncSessionsSuccess:  return "WorkoutHistoryView_SyncSessions_Success"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }
}
