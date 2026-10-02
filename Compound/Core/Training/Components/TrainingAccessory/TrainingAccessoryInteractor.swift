//
//  TrainingAccessoryInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

import SwiftUI

@MainActor
protocol TrainingAccessoryInteractor: GlobalInteractor {
    var activeSession: WorkoutSessionModel? { get }
    var restEndTime: Date? { get }
    #if !targetEnvironment(macCatalyst)
    func cancelRest()
    #endif
}

extension CoreInteractor: TrainingAccessoryInteractor { }
