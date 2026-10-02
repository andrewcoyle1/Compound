//
//  ExerciseCardItem.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import Foundation

struct ExerciseCardItem: Identifiable {
    let templateId: String
    let name: String
    /// Last 7 workouts including this exercise: (date, best 1-RM in that workout), already in
    /// `unitText`. Sets are stored in kilograms; weight unit is a per-exercise preference.
    let sparklineData: [(date: Date, value: Double)]
    /// Best estimated 1-RM, in `unitText`.
    let latest1RM: Double
    /// The exercise's own weight unit. Both cards used to print "kg" regardless, so a user who had
    /// set an exercise to pounds saw its kilogram number under a "kg" label while every other
    /// screen showed them pounds.
    let unitText: String

    var id: String { templateId }
}
