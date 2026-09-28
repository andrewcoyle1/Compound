//
//  TrainingAccessoryPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

@Observable
@MainActor
class TrainingAccessoryPresenter {
    
    private let interactor: TrainingAccessoryInteractor
    private let router: TrainingAccessoryRouter

    var activeSession: WorkoutSessionModel? {
        interactor.activeSession
    }
    
    init(
        interactor: TrainingAccessoryInteractor,
        router: TrainingAccessoryRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    var progress: Double {
        guard let active = interactor.activeSession else { return 0 }
        return Double(completedSetsCount(active)) / Double(totalSetsCount(active))
    }

    var progressLabel: String {
        guard let active = interactor.activeSession else { return "" }
        return String(localized: "\(String(describing: completedSetsCount(active)))/\(String(describing: totalSetsCount(active))) sets")
    }
    
    var isRestActive: Bool {
        guard let end = interactor.restEndTime else { return false }
        return Date() < end
    }
    
    var restEndTime: Date? {
        interactor.restEndTime
    }
    
    func reopenActiveSession() {
        router.showWorkoutTrackerView()
    }

    /// A left/right pair is one set, so the accessory's "4/12 sets" matches the screen behind it.
    func completedSetsCount(_ session: WorkoutSessionModel) -> Int {
        session.exercises.reduce(0) { $0 + $1.sets.fullyCompletedPairedSetCount }
    }

    func totalSetsCount(_ session: WorkoutSessionModel) -> Int {
        session.exercises.reduce(0) { $0 + $1.sets.pairedSetCount }
    }

    func totalVolume(_ session: WorkoutSessionModel) -> Double {
        session.exercises.flatMap(\.sets)
            .compactMap { set -> Double? in
                guard let weight = set.weightKg, let reps = set.reps else { return nil }
                return weight * Double(reps)
            }
            .reduce(0.0, +)
    }
}
