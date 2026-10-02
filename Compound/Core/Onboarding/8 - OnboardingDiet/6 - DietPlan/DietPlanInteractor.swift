//
//  DietPlanInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol DietPlanInteractor {
    var currentUser: UserModel? { get }
    func computeDietPlan(user: UserModel?, delegate: DietPlanDelegate) -> DietPlan
    func saveDietPlan(_ plan: DietPlan) async throws
    func trackEvent(event: LoggableEvent)
}

extension CoreInteractor: DietPlanInteractor { }
