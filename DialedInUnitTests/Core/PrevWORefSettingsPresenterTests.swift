//
//  PrevWORefSettingsPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The Previous Reference screen's snapshot of the settings document.
///
/// The screen itself — the two options, the tick, that a choice is saved — is covered in
/// `TrainingSettingsPresenterTests`. What is covered here is the thing those tests cannot see,
/// because they only ever save once: this screen edits a copy of the whole `WorkoutSettings`
/// document and writes the whole thing back, so the copy has to be the current one. Taken at init
/// and never refreshed, it silently reverts whatever another screen saved in the meantime.
@MainActor
struct PrevWORefSettingsStaleSnapshotTests {

    private final class Interactor: SpyGlobalInteractor, PrevWORefSettingsInteractor {
        var workoutSettings = WorkoutSettings(authorId: "user-1")
        private(set) var saved: [WorkoutSettings] = []

        func saveWorkoutSettings(_ workoutSettings: WorkoutSettings) async throws {
            saved.append(workoutSettings)
            self.workoutSettings = workoutSettings
        }
    }

    private final class Router: PreviousWorkoutReferenceSettingsRouter {
        let router: AnyRouter = TestRouting.anyRouter

        func showAlert(error: Error) { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
    }

    private struct Screen {
        let presenter: PrevWORefSettingsPresenter
        let interactor: Interactor
        let delegate = PrevWORefSettingsDelegate()
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        return Screen(
            presenter: PrevWORefSettingsPresenter(interactor: interactor, router: Router()),
            interactor: interactor
        )
    }

    /// Change the rest timer, walk into Previous Reference, pick an option — and the rest timer
    /// must still be what the user set it to. Before the re-read on appear it went back to whatever
    /// it had been when this screen was built, with nothing on screen to say so.
    @Test("Test A Choice Does Not Revert Settings Changed Elsewhere")
    func testAChoiceDoesNotRevertSettingsChangedElsewhere() async {
        let screen = makeScreen()

        // Another screen saves a different setting after this presenter was built.
        var changedElsewhere = screen.interactor.workoutSettings
        changedElsewhere.defaultRestDurationSeconds = 150
        changedElsewhere.rirTracking = true
        screen.interactor.workoutSettings = changedElsewhere

        screen.presenter.onViewAppear(delegate: screen.delegate)
        screen.presenter.previousWorkoutReference = .workoutsInMesocycle

        #expect(await TestManagers.eventually {
            screen.interactor.saved.last?.previousWorkoutReference == .workoutsInMesocycle
        })
        #expect(screen.interactor.saved.last?.defaultRestDurationSeconds == 150)
        #expect(screen.interactor.saved.last?.rirTracking == true)
    }

    // MARK: - The three scopes

    /// Three scopes, listed widest first. The screen is driven by `allCases`, so this is what the
    /// user sees.
    @Test("Test The Screen Lists All Three Scopes")
    func testTheScreenListsAllThreeScopes() {
        let screen = makeScreen()

        #expect(screen.presenter.options == [.anyExercise, .sameWorkout, .workoutsInMesocycle])
        #expect(screen.presenter.options.allSatisfy { option in
            !option.title.isEmpty && !option.subtitle.isEmpty
        })
    }

    /// The default, and the one nobody's stored setting may move off.
    @Test("Test The Default Scope Is This Workout")
    func testTheDefaultScopeIsThisWorkout() {
        #expect(makeScreen().presenter.previousWorkoutReference == .sameWorkout)
        #expect(WorkoutSettings(authorId: "user-1").previousWorkoutReference == .sameWorkout)
    }

    /// The migration rule. `"anyWorkout"` is what every existing user has stored and it has always
    /// meant "the last time this workout was done", whatever its title claimed — so it stays bound
    /// to `.sameWorkout` and the genuinely template-free scope took a new raw value.
    @Test("Test The Stored anyWorkout Value Still Means This Workout")
    func testTheStoredAnyWorkoutValueStillMeansThisWorkout() throws {
        #expect(PreviousWorkoutReferenceOption(rawValue: "anyWorkout") == .sameWorkout)
        #expect(PreviousWorkoutReferenceOption.sameWorkout.rawValue == "anyWorkout")
        #expect(PreviousWorkoutReferenceOption.anyExercise.rawValue == "anyExercise")

        let decoded = try JSONDecoder().decode(
            [PreviousWorkoutReferenceOption].self,
            from: Data(#"["anyWorkout","anyExercise","workoutsInProgram"]"#.utf8)
        )
        #expect(decoded == [.sameWorkout, .anyExercise, .workoutsInMesocycle])
    }

    /// And the re-read must not undo the user's own choice when the screen appears again after
    /// saving it.
    @Test("Test A Saved Choice Survives The Screen Reappearing")
    func testASavedChoiceSurvivesTheScreenReappearing() async {
        let screen = makeScreen()
        screen.presenter.previousWorkoutReference = .workoutsInMesocycle
        #expect(await TestManagers.eventually { screen.interactor.saved.count == 1 })

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.presenter.previousWorkoutReference == .workoutsInMesocycle)
    }
}
