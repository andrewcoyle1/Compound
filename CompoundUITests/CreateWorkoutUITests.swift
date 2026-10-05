//
//  CreateWorkoutUITests.swift
//  CompoundUITests
//

import XCTest

/// The workout template wizard: name, gym (skipped with the one mock gym), exercises, save.
@MainActor
final class CreateWorkoutUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The wizard opens on the name, and the mock account has one gym, so Continue lands on the
    /// define step with the exercise picker already open.
    private func reachTheDefineStep(_ app: XCUIApplication) {
        app.type("Push Day", into: "NameWorkout.name")
        app.tap("NameWorkout.continue")
    }

    func testAWorkoutWithTwoExercisesCanBeSaved() {
        let app = UITestApp.launch(startScreen: "STARTSCREEN_CREATE_WORKOUT")
        reachTheDefineStep(app)

        app.tap("ExerciseList.Plank")
        app.tap("ExerciseList.Push Up")
        app.tap("ExercisesPicker.confirm")

        app.tap("DefineWorkoutWrapper.save")
        app.assertDismissed("DefineWorkoutWrapper.save")
    }

    /// An empty template starts a workout with nothing in it, so Save stays off.
    func testSaveIsDisabledWithNoExercises() {
        let app = UITestApp.launch(startScreen: "STARTSCREEN_CREATE_WORKOUT")
        reachTheDefineStep(app)
        app.tap("ExercisesPicker.close")

        XCTAssertFalse(app.waitFor(app.button("DefineWorkoutWrapper.save")).isEnabled)
    }

    /// Reopening the picker starts from an empty selection, and confirming an exercise the
    /// workout already had used to add it a second time.
    func testReopeningThePickerDoesNotDuplicateAnExercise() {
        let app = UITestApp.launch(startScreen: "STARTSCREEN_CREATE_WORKOUT")
        reachTheDefineStep(app)

        app.tap("ExerciseList.Plank")
        app.tap("ExercisesPicker.confirm")

        app.tap("DefineWorkout.addExercise")
        app.tap("ExerciseList.Plank")
        app.tap("ExercisesPicker.confirm")

        app.waitFor(app.staticTexts["1 Exercise"].firstMatch)
    }
}
