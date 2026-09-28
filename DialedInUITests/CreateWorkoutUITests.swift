//
//  CreateWorkoutUITests.swift
//  DialedInUITests
//

import XCTest

/// The workout template wizard: splash, name, gym, exercises, save.
@MainActor
final class CreateWorkoutUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func reachTheDefineStep(_ app: XCUIApplication) {
        app.tap("CreateWorkout.continue")
        app.type("Push Day", into: "NameWorkout.name")
        app.tap("NameWorkout.continue")
        app.tap("ChooseGymProfile.profile")
    }

    func testAWorkoutWithTwoExercisesCanBeSaved() {
        let app = UITestApp.launch(startScreen: "STARTSCREEN_CREATE_WORKOUT")
        reachTheDefineStep(app)

        app.tap("DefineWorkout.addExercise")
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

        XCTAssertFalse(app.waitFor(app.button("DefineWorkoutWrapper.save")).isEnabled)
    }

    /// Reopening the picker starts from an empty selection, and confirming an exercise the
    /// workout already had used to add it a second time.
    func testReopeningThePickerDoesNotDuplicateAnExercise() {
        let app = UITestApp.launch(startScreen: "STARTSCREEN_CREATE_WORKOUT")
        reachTheDefineStep(app)

        app.tap("DefineWorkout.addExercise")
        app.tap("ExerciseList.Plank")
        app.tap("ExercisesPicker.confirm")

        app.tap("DefineWorkout.addExercise")
        app.tap("ExerciseList.Plank")
        app.tap("ExercisesPicker.confirm")

        app.waitFor(app.staticTexts["1 Exercise"].firstMatch)
    }
}
