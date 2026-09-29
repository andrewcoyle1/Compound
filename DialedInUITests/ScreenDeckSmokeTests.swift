//
//  ScreenDeckSmokeTests.swift
//  DialedInUITests
//

import XCTest

/// Launches every `STARTSCREEN_*` screen once and checks it renders without crashing.
///
/// The tests themselves are generated into `ScreenDeckSmokeTests+Screens.swift` by
/// `scripts/gen-smoke-tests.sh`. The suite only runs when the runner has `SMOKE=1`, which
/// xcodebuild passes through from `TEST_RUNNER_SMOKE=1`, so ordinary UI-test runs and CI skip it:
///
///     TEST_RUNNER_SMOKE=1 xcodebuild test … -only-testing:DialedInUITests/ScreenDeckSmokeTests
@MainActor
final class ScreenDeckSmokeTests: XCTestCase {

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SMOKE"] == "1", "Set TEST_RUNNER_SMOKE=1 to run the smoke suite")
    }

    /// The simulator runner sometimes fails to launch the app or loses its connection, so the
    /// first attempt's issues are expected and a failed first attempt gets one relaunch. A real
    /// crash or blank screen fails the second attempt too.
    func smoke(_ startScreen: String) {
        var app: XCUIApplication?
        XCTExpectFailure("First launch: the simulator runner is flaky", options: .nonStrict()) {
            let first = launch(startScreen)
            if screenAppeared(first) { app = first }
        }
        let attempt = app == nil ? 2 : 1
        let launched = app ?? launch(startScreen)

        XCTAssertTrue(screenAppeared(launched), "\(startScreen) showed no control or text within \(UITestApp.timeout)s")
        // Give a crash on appear a moment to happen before checking the app is still up.
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertEqual(launched.state, .runningForeground, "\(startScreen) is no longer running")

        let attachment = XCTAttachment(screenshot: launched.screenshot())
        attachment.name = "\(startScreen) (attempt \(attempt))"
        attachment.lifetime = .keepAlways
        add(attachment)
        launched.terminate()
    }

    private func launch(_ startScreen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "SIGNED_IN", startScreen]
        app.launchEnvironment["SMOKE"] = "1"
        app.launch()
        return app
    }

    /// Any `Screen.control` identifier or any static text counts as the screen having rendered.
    /// The UI-testing root is a blank frame until the screen's cover opens.
    private func screenAppeared(_ app: XCUIApplication) -> Bool {
        let control = app.descendants(matching: .any).matching(NSPredicate(format: "identifier CONTAINS '.'")).firstMatch
        let text = app.staticTexts.firstMatch
        let deadline = Date().addingTimeInterval(UITestApp.timeout)
        while Date() < deadline {
            if app.state != .runningForeground { return false }
            if control.exists || text.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }
}
