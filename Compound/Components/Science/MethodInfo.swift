//
//  MethodInfo.swift
//  Compound
//
//  What one calculation does and what it rests on, for the ⓘ button beside the figure it produces
//  (`MethodInfoButton`). Every number the app derives for the user, rather than reads back from
//  their logs, has one.
//
//  The values live in one file per area (`MethodInfo+Energy.swift`, `+Nutrition`, `+Training`,
//  `+Volume`, `+Habits`), each listing its own in `all…` so `MethodInfo.all` covers the app.
//
//  Keep each `summary` in plain words, put the equation in `formula` exactly as the code computes
//  it, and say in `ownChoices` which constants are Compound's own rather than a paper's, so the
//  sheet never presents a design choice as a finding.
//

import Foundation

struct MethodInfo: Identifiable, Sendable {
    let id: String
    let title: LocalizedStringResource
    /// How the figure is worked out, in a few sentences.
    let summary: LocalizedStringResource
    /// The equation as the code computes it. Not localized: symbols and numbers.
    let formula: String?
    /// How far to trust the figure: typical error, who it fits less well.
    let limitations: LocalizedStringResource?
    /// The constants Compound chose itself, with no study behind the exact value.
    let ownChoices: LocalizedStringResource?
    let citations: [Citation]

    init(
        id: String,
        title: LocalizedStringResource,
        summary: LocalizedStringResource,
        formula: String? = nil,
        limitations: LocalizedStringResource? = nil,
        ownChoices: LocalizedStringResource? = nil,
        citations: [Citation]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.formula = formula
        self.limitations = limitations
        self.ownChoices = ownChoices
        self.citations = citations
    }
}

extension MethodInfo {
    /// Every method, for the sources list in Settings.
    static var all: [MethodInfo] {
        allEnergy + allNutrition + allTraining + allVolume + allHabits
    }
}
