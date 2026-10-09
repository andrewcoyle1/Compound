//
//  ExpenditureEstimationMethodTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// `NutritionStrategySettings.estimationMethod` — which BMR equation the expenditure estimate
/// actually runs once the user's logged body fat is taken into account.
struct ExpenditureEstimationMethodTests {

    private func settings(
        method: ExpenditureEstimationMethod = .standard,
        equation: BMREquation = .mifflinStJeor
    ) -> NutritionStrategySettings {
        var settings = NutritionStrategySettings(authorId: "user-1")
        settings.estimationMethod = method
        settings.bmrEquation = equation
        return settings
    }

    // MARK: - Standard (the default)

    /// The default, and what every existing estimate already does: the equation picked on the row
    /// below is the equation that runs, body fat logged or not.
    @Test("Test Standard Keeps The Chosen Equation")
    func testStandardKeepsTheChosenEquation() {
        #expect(NutritionStrategySettings(authorId: "user-1").estimationMethod == .standard)

        for equation in BMREquation.allCases {
            let settings = settings(equation: equation)
            #expect(settings.resolvedBMREquation(bodyFatPercentage: nil) == equation)
            #expect(settings.resolvedBMREquation(bodyFatPercentage: 18) == equation)
        }
    }

    // MARK: - Body-fat aware

    /// Cunningham is the one equation in the app that reads body fat, so "use your logged body
    /// fat percentage" means running it.
    @Test("Test Body-Fat Aware Runs Cunningham When A Percentage Is Logged")
    func testBodyFatAwareRunsCunninghamWhenAPercentageIsLogged() {
        #expect(settings(method: .bodyFatAware).resolvedBMREquation(bodyFatPercentage: 18) == .cunningham)
        #expect(
            settings(method: .bodyFatAware, equation: .harrisBenedict)
                .resolvedBMREquation(bodyFatPercentage: 30) == .cunningham
        )
    }

    /// With nothing logged there is nothing to be aware of, and Cunningham would only fall
    /// back to Mifflin internally — so the equation the user picked stands instead.
    @Test("Test Body-Fat Aware Keeps The Chosen Equation With No Percentage")
    func testBodyFatAwareKeepsTheChosenEquationWithNoPercentage() {
        #expect(
            settings(method: .bodyFatAware, equation: .harrisBenedict)
                .resolvedBMREquation(bodyFatPercentage: nil) == .harrisBenedict
        )
    }

    /// A percentage outside 0–100 is not a body fat percentage. Lean mass computed from one would
    /// be zero or negative, so it is treated as nothing logged.
    @Test("Test An Impossible Percentage Is Treated As None")
    func testAnImpossiblePercentageIsTreatedAsNone() {
        let aware = settings(method: .bodyFatAware, equation: .harrisBenedict)

        #expect(aware.resolvedBMREquation(bodyFatPercentage: 0) == .harrisBenedict)
        #expect(aware.resolvedBMREquation(bodyFatPercentage: -5) == .harrisBenedict)
        #expect(aware.resolvedBMREquation(bodyFatPercentage: 100) == .harrisBenedict)
        #expect(aware.resolvedBMREquation(bodyFatPercentage: 140) == .harrisBenedict)
    }

    /// The two choices really do differ on the same inputs — otherwise the control is still
    /// decorative.
    @Test("Test The Two Methods Disagree On The Same Inputs")
    func testTheTwoMethodsDisagreeOnTheSameInputs() {
        let standard = settings(method: .standard, equation: .mifflinStJeor)
        let aware = settings(method: .bodyFatAware, equation: .mifflinStJeor)

        #expect(standard.resolvedBMREquation(bodyFatPercentage: 22) != aware.resolvedBMREquation(bodyFatPercentage: 22))
    }
}
