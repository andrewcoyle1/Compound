//
//  AppStateTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The one value that decides what the app shows on launch: onboarding, or the tab bar.
///
/// `AppView` switches on `startingModuleId` once, so this is read exactly at launch and never
/// again. Two things follow. `Dependencies` passes the module explicitly for every build
/// configuration, which is why the wrong id here would strand a signed-in user back in
/// onboarding. And the default — `UserDefaults.lastModuleId`, written by SwiftfulRouting as the
/// user moves between modules — is captured at init, so a module change later in the session
/// cannot move a running app out from under itself.
///
/// Serialized, and each test restores what was there: `UserDefaults.lastModuleId` is a real entry
/// in `UserDefaults.standard` with no injection point.
@Suite(.serialized)
@MainActor
struct AppStateTests {

    private func withLastModuleId(_ value: String?, _ body: () -> Void) {
        let key = "last_module_id"
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        body()
    }

    @Test("Test The Starting Module Is The One It Was Given")
    func testTheStartingModuleIsTheOneItWasGiven() {
        #expect(AppState(startingModuleId: Constants.tabBarModuleId).startingModuleId == Constants.tabBarModuleId)
        #expect(
            AppState(startingModuleId: Constants.onboardingModuleId).startingModuleId == Constants.onboardingModuleId
        )
    }

    /// An explicit module always wins, even when the last session ended somewhere else — that is
    /// how a signed-out launch sends the user to onboarding rather than back to the tab bar.
    @Test("Test An Explicit Module Beats The Stored One")
    func testAnExplicitModuleBeatsTheStoredOne() {
        withLastModuleId(Constants.tabBarModuleId) {
            #expect(AppState(startingModuleId: Constants.onboardingModuleId).startingModuleId
                    == Constants.onboardingModuleId)
        }
    }

    @Test("Test The Default Resumes The Last Module The User Was In")
    func testTheDefaultResumesTheLastModule() {
        withLastModuleId(Constants.tabBarModuleId) {
            #expect(AppState().startingModuleId == Constants.tabBarModuleId)
        }
    }

    /// Captured at init, not read on every access. `AppView` switches on it once, so a later write
    /// must not change what a running session thinks it launched into.
    @Test("Test A Later Module Change Does Not Move A Built App State")
    func testALaterModuleChangeDoesNotMoveABuiltAppState() {
        withLastModuleId(Constants.onboardingModuleId) {
            let state = AppState()

            UserDefaults.standard.set(Constants.tabBarModuleId, forKey: "last_module_id")

            #expect(state.startingModuleId == Constants.onboardingModuleId)
        }
    }

    /// The two modules the switch in `AppView` distinguishes. Equal ids would make the signed-out
    /// and signed-in launches indistinguishable.
    @Test("Test The Onboarding And Tab Bar Modules Are Different Destinations")
    func testTheOnboardingAndTabBarModulesAreDifferent() {
        #expect(Constants.onboardingModuleId != Constants.tabBarModuleId)
        #expect(Constants.onboardingModuleId.isEmpty == false)
        #expect(Constants.tabBarModuleId.isEmpty == false)
    }
}
