//
//  HeightInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol HeightInteractor {
    func trackEvent(event: LoggableEvent)
    func readHeightCentimetersFromAppleHealth() async -> Double?
}

extension CoreInteractor: HeightInteractor { }
