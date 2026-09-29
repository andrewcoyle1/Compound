//
//  ProfileInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol ProfileInteractor: GlobalInteractor, InviteLinkInteractor {
    var currentUser: UserModel? { get }
    var currentGoal: WeightGoal? { get }
    var currentDietPlan: DietPlan? { get }
    var isPremium: Bool { get }
}

extension CoreInteractor: ProfileInteractor { }
