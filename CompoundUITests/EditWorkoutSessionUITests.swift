//
//  EditWorkoutSessionUITests.swift
//  CompoundUITests
//

import XCTest

/// Correcting a finished workout: edit mode shows the tracker's own set rows, and a change saves.
@MainActor
final class EditWorkoutSessionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Save starts disabled, an added set enables it, and saving leaves edit mode.
    func testAnAddedSetCanBeSaved() {
        let app = UITestApp.launch(startScreen: "STARTSCREEN_SESSION_DETAIL")
        app.tap("SessionDetail.edit")

        let save = app.waitFor(app.button("SessionDetail.save"))
        XCTAssertFalse(save.isEnabled)

        app.waitFor(app.buttons["Add set"].firstMatch).tap()
        XCTAssertTrue(save.isEnabled)

        save.tap()
        app.waitFor(app.button("SessionDetail.edit"))
    }
}
