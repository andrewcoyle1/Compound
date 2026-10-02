//
//  AuthInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol AuthInteractor {
    var currentUser: UserModel? { get }
    var isPremium: Bool { get }
    func signInApple() async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func signInGoogle() async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func logIn(user: UserAuthInfo, isNewUser: Bool) async throws
    func trackEvent(event: LoggableEvent)
}

extension CoreInteractor: AuthInteractor { }
