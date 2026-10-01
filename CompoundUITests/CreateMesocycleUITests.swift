//
//  CreateMesocycleUITests.swift
//  CompoundUITests
//

import XCTest

/// The training mesocycle wizard: splash, name, icon, day design, save.
@MainActor
final class CreateMesocycleUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func reachTheDesignStep(_ app: XCUIApplication) {
        app.tap("CreateProgram.continue")
        app.type(" Block", into: "NameProgram.name")
        app.tap("NameProgram.continue")
        app.tap("ProgramIcon.continue")
    }

    func testAMesocycleWithOneWorkoutDayCanBeSaved() {
        let app = UITestApp.launch(startScreen: "STARTSCREEN_CREATE_PROGRAM")
        reachTheDesignStep(app)

        XCTAssertFalse(app.waitFor(app.button("ProgramDesign.save")).isEnabled)

        app.tap("DefineWorkout.addExercise")
        app.tap("ExerciseList.Plank")
        app.tap("ExercisesPicker.confirm")

        app.tap("ProgramDesign.save")
        app.assertDismissed("ProgramDesign.save")
    }

    /// Opened as a cover the first screen has a close button, which used to be missing from the
    /// library entry and left the flow with no way out.
    func testTheFirstScreenCanBeClosed() {
        let app = UITestApp.launch(startScreen: "STARTSCREEN_CREATE_PROGRAM")

        app.tap("CreateProgram.close")
        app.assertDismissed("CreateProgram.continue")
    }

    /// Back from the design step is the system's button, so it returns to the icon step. It used
    /// to be a drawn chevron that discarded the whole flow.
    func testBackFromTheDesignStepReturnsToTheIconStep() {
        let app = UITestApp.launch(startScreen: "STARTSCREEN_CREATE_PROGRAM")
        reachTheDesignStep(app)

        app.waitFor(app.navigationBars.buttons.firstMatch).tap()

        XCTAssertTrue(app.waitFor(app.button("ProgramIcon.continue")).exists)
    }
}
