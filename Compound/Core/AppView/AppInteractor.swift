//
//  AppInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol AppInteractor: GlobalInteractor {
    var auth: UserAuthInfo? { get }
    var startingModuleId: String { get }
    
    func logIn(user: UserAuthInfo, isNewUser: Bool) async throws
    func signInAnonymously() async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func saveUserFCMToken(token: String) async throws
    func applyLocalReminderSettings() async
    func syncAllRemoteDataIfLoggedIn() async
}

extension CoreInteractor: AppInteractor { }
