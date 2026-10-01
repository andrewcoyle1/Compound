//
//  DateOfBirthInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

import Foundation

@MainActor
protocol DateOfBirthInteractor {
    func trackEvent(event: LoggableEvent)
    func readDateOfBirthFromAppleHealth() async -> Date?
}

extension CoreInteractor: DateOfBirthInteractor { }
