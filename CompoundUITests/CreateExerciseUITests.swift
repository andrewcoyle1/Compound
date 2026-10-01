//
//  CreateExerciseUITests.swift
//  CompoundUITests
//

import XCTest

/// The five-step custom exercise wizard, driven end to end on the mock scenario.
@MainActor
final class CreateExerciseUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testABodyweightExerciseCanBeCreated() {
        let app = UITestApp.launch(startScreen: "STARTSCREEN_CREATE_EXERCISE")

        app.type("Pike Push Up", into: "CreateExercise.name")
        app.tap("CreateExercise.metricA")
        app.tap("EnumPicker.Reps")
        app.tap("CreateExercise.next")

        app.tap("MuscleGroupPicker.Front Delts")
        app.tap("MuscleGroupPicker.next")

        app.waitFor(app.switches["ExerciseEquipment.bodyweight"].firstMatch).tap()
        app.tap("ExerciseEquipment.next")

        app.tap("FinalExerciseDetails.next")
        app.tap("ExerciseSave.create")

        app.assertDismissed("ExerciseSave.create")
    }

    /// A name and one metric are both required before the first step can continue.
    func testNextIsDisabledUntilANameAndMetricAreGiven() {
        let app = UITestApp.launch(startScreen: "STARTSCREEN_CREATE_EXERCISE")

        let next = app.waitFor(app.button("CreateExercise.next"))
        XCTAssertFalse(next.isEnabled)

        app.type("Pike Push Up", into: "CreateExercise.name")
        XCTAssertFalse(next.isEnabled)

        app.tap("CreateExercise.metricA")
        app.tap("EnumPicker.Reps")
        XCTAssertTrue(next.isEnabled)
    }

    /// The contribution field only appears for bodyweight exercises and must be a percentage.
    func testAContributionOverOneHundredBlocksTheFinalStep() {
        let app = UITestApp.launch(startScreen: "STARTSCREEN_CREATE_EXERCISE")

        app.type("Pike Push Up", into: "CreateExercise.name")
        app.tap("CreateExercise.metricA")
        app.tap("EnumPicker.Reps")
        app.tap("CreateExercise.next")
        app.tap("MuscleGroupPicker.next")
        app.waitFor(app.switches["ExerciseEquipment.bodyweight"].firstMatch).tap()
        app.tap("ExerciseEquipment.next")

        let field = app.waitFor(app.textFields["FinalExerciseDetails.contribution"].firstMatch)
        field.tap()
        field.typeText("0")
        XCTAssertFalse(app.button("FinalExerciseDetails.next").isEnabled)
    }
}
