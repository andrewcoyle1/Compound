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

    /// A warm-up count set in an exercise's plan reads under it, and two exercises chosen from the
    /// list's edit mode become one superset carrying its letter.
    func testAWarmupCountAndASupersetShowOnTheRows() {
        let app = UITestApp.launch(startScreen: "STARTSCREEN_CREATE_WORKOUT")
        reachTheDefineStep(app)

        app.tap("ExerciseList.Plank")
        app.tap("ExerciseList.Push Up")
        app.tap("ExercisesPicker.confirm")

        app.tap("DefineWorkout.exercise.Plank")
        app.tap("SetTarget.warmupSets")
        app.waitFor(app.buttons["2"].firstMatch).tap()
        app.tap("SetTarget.save")
        assertLabel(of: app.button("DefineWorkout.exercise.Plank"), contains: "2 warm-ups")

        app.tap("DefineWorkout.edit")
        app.tap("DefineWorkout.superset")
        app.tap("DefineWorkout.exercise.Plank")
        app.tap("DefineWorkout.exercise.Push Up")
        app.tap("DefineWorkout.confirmSuperset")

        assertLabel(of: app.button("DefineWorkout.exercise.Plank"), contains: "Superset A")
        assertLabel(of: app.button("DefineWorkout.exercise.Push Up"), contains: "Superset A")
    }

    private func assertLabel(of element: XCUIElement, contains text: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: UITestApp.timeout), .completed, "\(element) never read \(text)", file: file, line: line)
    }
}
