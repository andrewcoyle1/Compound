//
//  OnboardingUITests.swift
//  DialedInUITests
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

        app.waitFor(app.buttons["Skip for now"].firstMatch).tap()
        app.continueFrom("🎉 Onboarding Complete!")
        app.waitFor(app.tabBars.firstMatch)
    }

    /// Welcome, intro, auth, then the subscription pitch and the mock paywall: pick the first
    /// product and subscribe. Get Started waits on the anonymous sign-in.
    private func signUp(_ app: XCUIApplication) {
        app.tapWhenEnabled("GetStartedButton")
        app.continueFrom("Welcome to Compound.")
        app.waitFor(app.element("Auth.apple")).tap()
        app.continueFrom("Why subscribe?")
        app.waitFor(app.staticTexts["START"].firstMatch).tap()
        app.tap("Subscribe")
    }

    private func completeAccountSetup(_ app: XCUIApplication) {
        app.continueFrom("The Basics")
        app.waitFor(app.textFields.firstMatch).tap()
        app.textFields.firstMatch.typeText("Test")
        app.continueFrom("Your Name")
        app.choose("Male", on: "Select your gender")
        app.continueFrom("When were you born?")
        app.continueFrom("How tall are you?")
        app.continueFrom("What's your weight?")
        app.choose("Never", on: "How often do you exercise?")
        app.choose("Sedentary", on: "What's your daily activity level outside of exercise?")
        app.choose("Beginner", on: "How would you rate your cardiovascular fitness?")
        app.continueFrom("kcal/day")
        // Notifications and health data only appear where their permission can still be
        // asked; the mock scenario asks for neither. Skip whichever of them shows.
        let disclaimer = app.switches["HealthDisclaimerToggle"].firstMatch
        while disclaimer.waitForExistence(timeout: 3) == false {
            app.tap("SkipForNow")
        }
        // The identifier sits on the labelled row; the control that flips is the switch inside it.
        disclaimer.switches.firstMatch.tap()
        app.switches["HealthPrivacyPolicyToggle"].firstMatch.switches.firstMatch.tap()
        app.continueFrom("Health Disclaimer")
        app.waitFor(app.buttons["I Agree & Continue"].firstMatch).tap()
    }

    /// Lose weight, one target below the 70 kg default, at the default rate.
    private func setGoal(_ app: XCUIApplication) {
        app.continueFrom("Goal")
        app.choose("Lose weight", on: "Choose one")
        app.waitFor(app.staticTexts["Target Weight"].firstMatch)
        app.waitFor(app.pickerWheels.firstMatch).adjust(toPickerWheelValue: "65 kg")
        app.tapWhenEnabled("Continue")
        app.continueFrom("At what rate?")
        app.continueFrom("Goal Summary")
    }

    /// A named gym profile (the equipment screen's Continue makes it the favourite), then a
    /// program by the same path CreateProgramUITests takes.
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
        // Activating offers to keep the program's days as standalone workout templates.
        app.waitFor(app.buttons["No"].firstMatch).tap()
    }

    private func setUpDiet(_ app: XCUIApplication) {
        app.continueFrom("Diet Program")
        app.choose("Balanced", on: nil)
        app.choose("Standard Floor (Recommended)", on: nil)
        app.choose("Distribute Evenly", on: nil)
        app.choose("Low", on: nil)
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
