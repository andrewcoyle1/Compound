//
//  CreateExerciseInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 28/11/2025.
//

import SwiftUI

/// The first screen collects fields and hands them on; nothing is saved or generated here.
@MainActor
protocol CreateExerciseInteractor: GlobalInteractor { }

extension CoreInteractor: CreateExerciseInteractor { }
