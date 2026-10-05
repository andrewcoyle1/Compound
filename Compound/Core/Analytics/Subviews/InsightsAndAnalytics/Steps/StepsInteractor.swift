//
//  StepsInteractor.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@MainActor
protocol StepsInteractor: GlobalInteractor {
    var userId: String? { get }
    var stepsHistory: [StepsModel] { get }
    func syncStepsFromHealthKit(fromScratch: Bool) async
    func canRequestHealthDataAuthorisation() -> Bool
    func requestHealthKitAuthorisation(for scope: HealthDataScope) async throws
}

extension CoreInteractor: StepsInteractor { }
