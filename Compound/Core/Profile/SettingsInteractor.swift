//
//  SettingsInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol SettingsInteractor: GlobalInteractor, InviteLinkInteractor {
    var auth: UserAuthInfo? { get }
    var currentUser: UserModel? { get }
    var currentGoal: WeightGoal? { get }
    func signOut() async throws
    var currentDietPlan: DietPlan? { get }
    var isPremium: Bool { get }
}

extension CoreInteractor: SettingsInteractor { }
