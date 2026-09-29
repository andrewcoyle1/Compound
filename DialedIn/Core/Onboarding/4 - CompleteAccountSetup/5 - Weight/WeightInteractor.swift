//
//  WeightInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol WeightInteractor {
    func trackEvent(event: LoggableEvent)
    func readWeightKilogramsFromAppleHealth() async -> Double?
}

extension CoreInteractor: WeightInteractor { }
