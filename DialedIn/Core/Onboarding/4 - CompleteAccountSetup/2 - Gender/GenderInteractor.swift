//
//  GenderInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol GenderInteractor: GlobalInteractor {
    func readSexFromAppleHealth() async -> Gender?
}

extension CoreInteractor: GenderInteractor { }
