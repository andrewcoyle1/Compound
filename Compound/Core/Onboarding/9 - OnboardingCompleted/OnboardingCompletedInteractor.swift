//
//  OnboardingCompletedInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol OnboardingCompletedInteractor: GlobalInteractor {
    func saveOnboardingComplete() async throws
}

extension CoreInteractor: OnboardingCompletedInteractor { }
