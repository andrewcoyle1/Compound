//
//  TimerDurationPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The per-exercise rest override, which two screens write.
///
/// `ExerciseSettingsPresenter` and this screen both put a value into
/// `ExerciseSettingsModel.restDurationOverride` through the same picker, and they have to agree on
/// what an empty picker means — otherwise the same gesture clears the override on one screen and
/// stores a zero-second rest on the other, and the list here gains a row reading "0:00".
@MainActor
struct TimerDurationExerciseOverrideTests {

    private final class Interactor: SpyGlobalInteractor, TimerDurationInteractor {
        var workoutSettings = WorkoutSettings(authorId: "user-1")
        var allExercises: [ExerciseModel] = []
        var allExerciseSettings: [ExerciseSettingsModel] = []
        private(set) var savedOverrides: [(id: String, seconds: Int?)] = []

        var saveError: Error?

        func saveWorkoutSettings(_ workoutSettings: WorkoutSettings) async throws {
            if let saveError { throw saveError }
            self.workoutSettings = workoutSettings
        }

        func exerciseRestOverride(for exerciseId: String) -> Int? {
            allExerciseSettings.first(where: { $0.id == exerciseId })?.restDurationOverride
        }

        func setExerciseRestOverride(_ seconds: Int?, for exerciseId: String) async throws {
            if let saveError { throw saveError }
            savedOverrides.append((id: exerciseId, seconds: seconds))
        }
    }

    private final class Router: TimerDurationRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []

        func showAlert(error: Error) { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    private struct Screen {
        let presenter: TimerDurationPresenter
        let interactor: Interactor
        let delegate = TimerDurationDelegate()
    }

    private func makeScreen(exercises: [ExerciseModel] = []) -> Screen {
        let interactor = Interactor()
        interactor.allExercises = exercises
        return Screen(
            presenter: TimerDurationPresenter(interactor: interactor, router: Router()),
            interactor: interactor
        )
    }

    @Test("Test An Empty Picker Clears The Exercise Override")
    func testAnEmptyPickerClearsTheExerciseOverride() async {
        let screen = makeScreen()
        screen.presenter.onEditExerciseOverridePressed(
            TimerDurationPresenter.ExerciseOverride(id: "exercise-1", name: "Bench Press", seconds: 120)
        )

        screen.presenter.editMinutes = 0
        screen.presenter.editSeconds = 0
        screen.presenter.saveExerciseEdit()

        #expect(await TestManagers.eventually { screen.interactor.savedOverrides.count == 1 })
        #expect(screen.interactor.savedOverrides.last?.id == "exercise-1")
        #expect(screen.interactor.savedOverrides.last?.seconds == nil)
    }

    @Test("Test A Chosen Duration Is Saved As Entered")
    func testAChosenDurationIsSavedAsEntered() async {
        let screen = makeScreen()
        screen.presenter.onEditExerciseOverridePressed(
            TimerDurationPresenter.ExerciseOverride(id: "exercise-1", name: "Bench Press", seconds: 120)
        )

        screen.presenter.editMinutes = 2
        screen.presenter.editSeconds = 30
        screen.presenter.saveExerciseEdit()

        #expect(await TestManagers.eventually { screen.interactor.savedOverrides.last?.seconds == 150 })
    }

    /// The per-type durations are the other half of this screen, and they live in the shared
    /// `WorkoutSettings` document — so they carry the same re-read on appear the sibling screens do.
    @Test("Test A Type Duration Does Not Revert Settings Changed Elsewhere")
    func testATypeDurationDoesNotRevertSettingsChangedElsewhere() async {
        let screen = makeScreen()

        var changedElsewhere = screen.interactor.workoutSettings
        changedElsewhere.defaultRestDurationSeconds = 150
        screen.interactor.workoutSettings = changedElsewhere

        screen.presenter.onViewAppear(delegate: screen.delegate)
        screen.presenter.onEditPressed(type: .core)
        screen.presenter.editMinutes = 1
        screen.presenter.editSeconds = 0
        screen.presenter.saveEdit()

        #expect(await TestManagers.eventually {
            screen.interactor.workoutSettings.restDurationsByExerciseType["core"] == 60
        })
        #expect(screen.interactor.workoutSettings.defaultRestDurationSeconds == 150)
    }

    /// Both writes on this screen were `try?`-ed. A failure now raises one alert and one event.
    @Test("Test A Failed Override Save Alerts Once")
    func testAFailedOverrideSaveAlertsOnce() async {
        let interactor = Interactor()
        interactor.saveError = URLError(.notConnectedToInternet)
        let router = Router()
        let presenter = TimerDurationPresenter(interactor: interactor, router: router)

        presenter.removeExerciseOverride(
            TimerDurationPresenter.ExerciseOverride(id: "exercise-1", name: "Bench Press", seconds: 120)
        )

        #expect(await TestManagers.eventually(timeout: .seconds(5)) { !router.alertTitles.isEmpty })
        for _ in 0..<10 { await Task.yield() }
        #expect(router.alertTitles == ["Unable to Save Settings"])
        #expect(interactor.trackedEventNames == ["TimerDurationView_Save_Fail"])
    }

    @Test("Test A Failed Type Duration Save Alerts Once")
    func testAFailedTypeDurationSaveAlertsOnce() async {
        let interactor = Interactor()
        interactor.saveError = URLError(.notConnectedToInternet)
        let router = Router()
        let presenter = TimerDurationPresenter(interactor: interactor, router: router)

        presenter.resetDefaults()

        #expect(await TestManagers.eventually(timeout: .seconds(5)) { !router.alertTitles.isEmpty })
        for _ in 0..<10 { await Task.yield() }
        #expect(router.alertTitles == ["Unable to Save Settings"])
        #expect(interactor.trackedEventNames == ["TimerDurationView_Save_Fail"])
    }
}
