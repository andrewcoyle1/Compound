//
//  LogMeasurementInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 21/09/2026.
//

import SwiftUI

@MainActor
protocol LogMeasurementInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var bodyMeasurements: [BodyMeasurementEntry] { get }
    func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws
}

extension CoreInteractor: LogMeasurementInteractor { }
