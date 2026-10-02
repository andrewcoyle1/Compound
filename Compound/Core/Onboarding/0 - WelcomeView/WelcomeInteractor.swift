//
//  WelcomeInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

protocol WelcomeInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var isPremium: Bool { get }
}

extension CoreInteractor: WelcomeInteractor { }
