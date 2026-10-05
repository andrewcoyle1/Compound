//
//  OnboardingUITests.swift
//  CompoundUITests
//

import XCTest

/// A brand-new user walks the whole onboarding flow, from Welcome to the tab bar, on the mock
/// scenario. Every screen is anchored on something only it shows before its Continue is tapped,
/// because most screens share the bare `Continue` identifier.
@MainActor
final class OnboardingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testANewUserCanCompleteOnboarding() {
        let app = UITestApp.launchNewUser()
        signUp(app)
        completeAccountSetup(app)
        setGoal(app)
        setUpTraining(app)
        setUpDiet(app)

        // Accepting the diet plan finishes onboarding: no completion screen in between.
        app.waitFor(app.tabBars.firstMatch)
    }

    /// Welcome, auth, then the subscription pitch and the mock paywall, which opens with its
    /// first plan chosen, so Subscribe is ready. Get Started waits on the anonymous sign-in.
    private func signUp(_ app: XCUIApplication) {
        app.tapWhenEnabled("GetStartedButton")
        app.waitFor(app.element("Auth.apple")).tap()
        app.continueFrom("Why Subscribe?")
        app.tapWhenEnabled("Subscribe")
    }

    private func completeAccountSetup(_ app: XCUIApplication) {
        app.waitFor(app.textFields.firstMatch).tap()
        app.textFields.firstMatch.typeText("Test")
        app.continueFrom("Your Name")
        app.choose("Male", on: "Sex for Calorie Estimate")
        app.continueFrom("When Were You Born?")
        app.continueFrom("How Tall Are You?")
        app.continueFrom("What's Your Weight?")
        app.choose("Never", on: "Do You Work Out?")
        // No cardio fitness step any more: activity leads straight to the expenditure estimate.
        app.choose("Sedentary", on: "How Active Are You?")
        app.continueFrom("kcal/day")
        let disclaimer = app.waitFor(app.switches["HealthDisclaimerToggle"].firstMatch)
        // The identifier sits on the labelled row; the control that flips is the switch inside it.
        disclaimer.switches.firstMatch.tap()
        app.switches["HealthPrivacyPolicyToggle"].firstMatch.switches.firstMatch.tap()
        // Continue saves the consent directly; the confirmation alert that followed is gone.
        app.continueFrom("Health Disclaimer")
    }

    /// Lose weight, one target below the 70 kg default, at the default rate.
    private func setGoal(_ app: XCUIApplication) {
        app.choose("Lose weight", on: "Your goal generates a custom plan to get you there. This can be changed later, and your plan will update accordingly.")
        app.waitFor(app.staticTexts["What's Your Target?"].firstMatch)
        app.waitFor(app.pickerWheels.firstMatch).adjust(toPickerWheelValue: "65 kg")
        app.tapWhenEnabled("Continue")
        app.continueFrom("At What Rate?")
        app.continueFrom("Does This Look Right?")
    }

    /// A named gym profile (the equipment screen's Continue makes it the favourite), then a
    /// mesocycle by the same path CreateMesocycleUITests takes.
    private func setUpTraining(_ app: XCUIApplication) {
        app.waitFor(app.staticTexts["What would you like to name this gym?"].firstMatch)
        app.textFields.firstMatch.tap()
        app.textFields.firstMatch.typeText("Home")
        app.tapWhenEnabled("Continue")
        app.waitFor(app.searchFields.firstMatch)
        app.tapWhenEnabled("Continue")

        app.tap("CreateProgram.continue")
        app.type(" Block", into: "NameProgram.name")
        app.tap("NameProgram.continue")
        app.tap("ProgramIcon.continue")
        app.tap("DefineWorkout.addExercise")
        app.tap("ExerciseList.Plank")
        app.tap("ExercisesPicker.confirm")
        app.tapWhenEnabled("ProgramDesign.activate")
        // Activating offers to keep the mesocycle's days as standalone workout templates.
        app.waitFor(app.buttons["Don't Save"].firstMatch).tap()
    }

    private func setUpDiet(_ app: XCUIApplication) {
        app.waitFor(app.staticTexts["Diet Program"].firstMatch)
        app.tapWhenEnabled("UseRecommendedPlan")
        app.continueFrom("Estimated TDEE", expected: false)
    }
}

private extension XCUIApplication {

    /// Waits for `anchor` text to identify the screen, then taps its Continue once it is enabled.
    /// `expected: false` matches the anchor as a prefix, for texts that carry a computed value.
    func continueFrom(_ anchor: String, expected: Bool = true, file: StaticString = #filePath, line: UInt = #line) {
        waitFor(anchorText(anchor, exact: expected), file: file, line: line)
        tapWhenEnabled("Continue", file: file, line: line)
    }

    /// Selects one option row by its label, on the screen `anchor` identifies (nil skips the check).
    func choose(_ option: String, on anchor: String?, file: StaticString = #filePath, line: UInt = #line) {
        if let anchor { waitFor(anchorText(anchor, exact: true), file: file, line: line) }
        waitFor(staticTexts[option].firstMatch, file: file, line: line).tap()
        tapWhenEnabled("Continue", file: file, line: line)
    }

    func tapWhenEnabled(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = waitFor(self.button(identifier), file: file, line: line)
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: button)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: UITestApp.timeout), .completed, "\(identifier) stayed disabled", file: file, line: line)
        button.tap()
    }

    private func anchorText(_ anchor: String, exact: Bool) -> XCUIElement {
        if exact { return staticTexts[anchor].firstMatch }
        return staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", anchor)).firstMatch
    }
}
