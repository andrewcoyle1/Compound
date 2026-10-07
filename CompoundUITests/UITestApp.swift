//
//  UITestApp.swift
//  CompoundUITests
//

import XCTest

/// Launches the app straight onto one creation flow, signed in to the mock scenario.
///
/// `AppViewForUITesting` reads the `STARTSCREEN_*` argument and mounts that flow on its own
/// router, so a test starts on the flow's first screen instead of walking the tab bar to it.
enum UITestApp {

    static let timeout: TimeInterval = 10

    static func launch(startScreen: String, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "SIGNED_IN", startScreen] + arguments
        app.launch()
        return app
    }

    /// Launches the app as a first-time user: the mock `newAnonymous` scenario, no
    /// `STARTSCREEN_`, so the root is the real onboarding flow from the Welcome screen.
    static func launchNewUser() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
        return app
    }
}

extension XCUIApplication {

    /// Any element carrying the identifier. Identifiers are set on SwiftUI containers as often
    /// as on the control itself, so this does not assume an element type.
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func button(_ identifier: String) -> XCUIElement {
        buttons[identifier].firstMatch
    }

    @discardableResult
    func waitFor(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: UITestApp.timeout), "\(element) did not appear", file: file, line: line)
        return element
    }

    func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        waitFor(button(identifier), file: file, line: line).tap()
    }

    func type(_ text: String, into identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = waitFor(textFields[identifier].firstMatch, file: file, line: line)
        // On a cold launch the first tap can land while the flow is still presenting and be lost,
        // and typing then fails with "Neither element nor any descendant has keyboard focus". So
        // tap again until the field has focus before typing.
        let focus = NSPredicate(format: "hasKeyboardFocus == true")
        for _ in 0..<3 {
            field.tap()
            if XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: focus, object: field)], timeout: 2) == .completed { break }
        }
        XCTAssertTrue(focus.evaluate(with: field), "\(identifier) never took focus", file: file, line: line)
        field.typeText(text)
    }

    /// The flow's cover has gone when its first screen's control is no longer on screen.
    func assertDismissed(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: button(identifier))
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: UITestApp.timeout), .completed, "\(identifier) is still on screen", file: file, line: line)
    }
}
