//
//  NameWorkoutInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

import SwiftUI

@MainActor
protocol NameWorkoutInteractor: GlobalInteractor {
    var gymProfiles: [GymProfileModel] { get }
}

extension CoreInteractor: NameWorkoutInteractor { }
