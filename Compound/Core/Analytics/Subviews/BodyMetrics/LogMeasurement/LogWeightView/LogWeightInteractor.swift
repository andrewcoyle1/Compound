//
//  LogWeightInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

import SwiftUI

@MainActor
protocol LogWeightInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var bodyMeasurements: [BodyMeasurementEntry] { get }
    func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws
    func updateWeight(userId: String, weight: Double, weightUnitPreference: WeightUnitPreference) async throws
}

extension CoreInteractor: LogWeightInteractor { }
