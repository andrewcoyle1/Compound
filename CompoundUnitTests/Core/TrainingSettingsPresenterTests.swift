//
//  TrainingSettingsPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

//
//  The workout settings screens.
//
//  All five of these edit one document — every toggle on every one of them writes the whole
//  `WorkoutSettings` back. Each presenter holds its own copy of that document, which is what makes
//  them worth testing: a copy taken when the screen was built goes stale the moment another screen
//  saves, and saving a stale copy does not fail, it quietly reinstates the old values of everything
//  the user changed in between.
//
//  So the questions here are whether a toggle reaches storage at all, and whether flipping one
//  leaves the rest of the document as it was.
//

/// A spy standing in for the settings manager, shared by the screens that only read and write the
/// settings document.
@MainActor
private final class SettingsInteractor: SpyGlobalInteractor,
                                        WorkoutSettingsInteractor,
                                        RestTimerSettingsInteractor,
                                        SmartProgressionSettingsInteractor,
                                        PrevWORefSettingsInteractor {
    var workoutSettings = WorkoutSettings(authorId: "user-1")
    private(set) var savedSettings: [WorkoutSettings] = []

    /// Saving mirrors the manager: the document that comes back to the next reader is the one that
    /// was last written.
    func saveWorkoutSettings(_ workoutSettings: WorkoutSettings) async throws {
        savedSettings.append(workoutSettings)
        self.workoutSettings = workoutSettings
    }
}

/// Saving happens in a detached `Task`, so a test has to let the loop turn before asserting.
private func settleSettings() async {
    for _ in 0..<10 {
        await Task.yield()
    }
}

/// The top of the workout settings, and the way in to the four screens below it.
@MainActor
struct WorkoutSettingsPresenterTests {

    private final class Router: WorkoutSettingsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        func showRestTimerSettingsView(delegate: RestTimerSettingsDelegate) { shown.append("restTimer") }
        func showSmartProgressionSettingsView(delegate: SmartProgressionSettingsDelegate) { shown.append("smartProgression") }
        func showPreviousWorkoutReferenceSettingsView(delegate: PrevWORefSettingsDelegate) { shown.append("previousReference") }
        func showExerciseAssessmentView(delegate: ExerciseAssessmentDelegate) { shown.append("exerciseAssessment") }
    }

    private struct Screen {
        let presenter: WorkoutSettingsPresenter
        let interactor: SettingsInteractor
        let router: Router
    }

    private func makeScreen(_ settings: WorkoutSettings = WorkoutSettings(authorId: "user-1")) -> Screen {
        let interactor = SettingsInteractor()
        interactor.workoutSettings = settings
        let router = Router()
        return Screen(
            presenter: WorkoutSettingsPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - Reading and writing

    @Test("Test The Toggles Show What Is Stored")
    func testTheTogglesShowWhatIsStored() {
        var settings = WorkoutSettings(authorId: "user-1")
        settings.rirTracking = true
        settings.keepAlive = false
        settings.addSmartWarmUps = false
        let screen = makeScreen(settings)

        #expect(screen.presenter.rirTracking)
        #expect(!screen.presenter.keepAlive)
        #expect(!screen.presenter.addSmartWarmUps)
    }

    @Test("Test Flipping A Toggle Is Saved")
    func testFlippingAToggleIsSaved() async {
        let screen = makeScreen()

        screen.presenter.rirTracking = true
        await settleSettings()

        #expect(screen.presenter.rirTracking)
        #expect(screen.interactor.savedSettings.last?.rirTracking == true)
    }

    /// The whole document is written on every toggle, so one switch must not carry the defaults of
    /// the others over the values already stored.
    @Test("Test Flipping One Toggle Leaves The Others Alone")
    func testFlippingOneToggleLeavesTheOthersAlone() async {
        var settings = WorkoutSettings(authorId: "user-1")
        settings.propagateChanges = true
        settings.showWorkoutTimer = false
        settings.defaultRestDurationSeconds = 150
        let screen = makeScreen(settings)

        screen.presenter.exerciseAutoNext = false
        await settleSettings()

        let saved = screen.interactor.savedSettings.last
        #expect(saved?.exerciseAutoNext == false)
        #expect(saved?.propagateChanges == true)
        #expect(saved?.showWorkoutTimer == false)
        #expect(saved?.defaultRestDurationSeconds == 150)
    }

    /// The screens this one pushes to edit the same document while it stays alive underneath them.
    /// Without re-reading on the way back, the next toggle flipped here would write a copy taken
    /// before the visit and undo everything done there.
    @Test("Test Returning From Another Settings Screen Keeps Its Changes")
    func testReturningFromAnotherSettingsScreenKeepsItsChanges() async {
        let screen = makeScreen()

        // The rest timer screen, pushed on top of this one, saves a change of its own.
        var changedElsewhere = screen.interactor.workoutSettings
        changedElsewhere.defaultRestDurationSeconds = 240
        changedElsewhere.restTimerVibrate = false
        screen.interactor.workoutSettings = changedElsewhere

        screen.presenter.onViewAppear(delegate: WorkoutSettingsDelegate())
        screen.presenter.keepAlive = false
        await settleSettings()

        let saved = screen.interactor.savedSettings.last
        #expect(saved?.keepAlive == false)
        #expect(saved?.defaultRestDurationSeconds == 240)
        #expect(saved?.restTimerVibrate == false)
    }

    // MARK: - Navigation

    @Test("Test Each Row Opens Its Own Settings Screen")
    func testEachRowOpensItsOwnSettingsScreen() {
        let screen = makeScreen()

        screen.presenter.onRestTimerSettingsPressed()
        screen.presenter.onSmartProgressionSettingsPressed()
        screen.presenter.onPreviousReferenceSettingsPressed()
        screen.presenter.onExerciseAssessmentPressed()

        #expect(screen.router.shown == ["restTimer", "smartProgression", "previousReference", "exerciseAssessment"])
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: WorkoutSettingsDelegate())

        #expect(screen.interactor.trackedScreenEventNames == ["WorkoutSettingsView_Appear"])
    }
}

/// The rest timer: whether it runs, what it sounds like, and how long the rest between different
/// kinds of set is scaled to.
@MainActor
struct RestTimerSettingsPresenterTests {

    private final class Router: RestTimerSettingsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        func showTimerDurationView(delegate: TimerDurationDelegate) { shown.append("timerDuration") }
    }

    private struct Screen {
        let presenter: RestTimerSettingsPresenter
        let interactor: SettingsInteractor
        let router: Router
    }

    private func makeScreen(_ settings: WorkoutSettings = WorkoutSettings(authorId: "user-1")) -> Screen {
        let interactor = SettingsInteractor()
        interactor.workoutSettings = settings
        let router = Router()
        return Screen(
            presenter: RestTimerSettingsPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    @Test("Test Flipping A Rest Timer Toggle Is Saved")
    func testFlippingARestTimerToggleIsSaved() async {
        let screen = makeScreen()

        screen.presenter.restBetweenExercises = false
        await settleSettings()

        #expect(screen.interactor.savedSettings.last?.restBetweenExercises == false)
    }

    /// Turning the sound off must not also turn the vibration off, or the timer would go silent in
    /// both senses at once.
    @Test("Test Flipping One Rest Toggle Leaves The Others Alone")
    func testFlippingOneRestToggleLeavesTheOthersAlone() async {
        var settings = WorkoutSettings(authorId: "user-1")
        settings.restAfterLastWarmUp = true
        settings.restBetweenSideSets = true
        let screen = makeScreen(settings)

        screen.presenter.restTimerPlaySound = false
        await settleSettings()

        let saved = screen.interactor.savedSettings.last
        #expect(saved?.restTimerPlaySound == false)
        #expect(saved?.restTimerVibrate == true)
        #expect(saved?.restAfterLastWarmUp == true)
        #expect(saved?.restBetweenSideSets == true)
    }

    /// The scalings are shown as percentages of the exercise's own rest, so three quarters reads as
    /// 75%, not 0.75 or 7500%.
    @Test("Test A Scaling Reads As A Percentage")
    func testAScalingReadsAsAPercentage() {
        let screen = makeScreen()

        #expect(screen.presenter.formattedScaling(0.75) == "75%")
        #expect(screen.presenter.formattedScaling(1) == "100%")
        #expect(screen.presenter.formattedScaling(0.5) == "50%")
        // Rounded rather than truncated, so a third does not read as 33% one way and 34% the other.
        #expect(screen.presenter.formattedScaling(0.336) == "34%")
    }

    /// Three scaling pickers share one write path, so each has to write back to its own setting.
    @Test("Test Each Scaling Is Edited On Its Own")
    func testEachScalingIsEditedOnItsOwn() async {
        let screen = makeScreen()

        #expect(screen.presenter.currentScaling(for: .betweenExercises) == 1)

        screen.presenter.updateScaling(for: .betweenExercises, value: 1.25)
        await settleSettings()

        let saved = screen.interactor.savedSettings.last
        #expect(saved?.betweenExercisesRestScaling == 1.25)
        #expect(saved?.warmUpRestScaling == 0.75)
        #expect(saved?.sideSetRestScaling == 0.5)
    }

    @Test("Test Each Scaling Is Read From Its Own Setting")
    func testEachScalingIsReadFromItsOwnSetting() {
        var settings = WorkoutSettings(authorId: "user-1")
        settings.warmUpRestScaling = 0.4
        settings.betweenExercisesRestScaling = 1.5
        settings.sideSetRestScaling = 0.25
        let screen = makeScreen(settings)

        #expect(screen.presenter.currentScaling(for: .warmUp) == 0.4)
        #expect(screen.presenter.currentScaling(for: .betweenExercises) == 1.5)
        #expect(screen.presenter.currentScaling(for: .sideSets) == 0.25)
    }

    /// The durations screen is pushed on top of this one and saves the same document, so this one
    /// re-reads on the way back rather than writing over what was set there.
    @Test("Test Returning From The Durations Screen Keeps Its Changes")
    func testReturningFromTheDurationsScreenKeepsItsChanges() async {
        let screen = makeScreen()

        var changedElsewhere = screen.interactor.workoutSettings
        changedElsewhere.restDurationsByExerciseType = ["compoundUpper": 240]
        screen.interactor.workoutSettings = changedElsewhere

        screen.presenter.onViewAppear(delegate: RestTimerSettingsDelegate())
        screen.presenter.useRestTimers = false
        await settleSettings()

        #expect(screen.interactor.savedSettings.last?.restDurationsByExerciseType == ["compoundUpper": 240])
    }

    @Test("Test The Durations Row Opens The Durations Screen")
    func testTheDurationsRowOpensTheDurationsScreen() {
        let screen = makeScreen()

        screen.presenter.onTimerDurationPressed()

        #expect(screen.router.shown == ["timerDuration"])
    }
}

/// How the app fills a set in before it is done, and whether it adjusts mid-workout.
@MainActor
struct SmartProgressionSettingsPresenterTests {

    private final class Router: SmartProgressionSettingsRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private struct Screen {
        let presenter: SmartProgressionSettingsPresenter
        let interactor: SettingsInteractor
    }

    private func makeScreen(_ settings: WorkoutSettings = WorkoutSettings(authorId: "user-1")) -> Screen {
        let interactor = SettingsInteractor()
        interactor.workoutSettings = settings
        return Screen(
            presenter: SmartProgressionSettingsPresenter(interactor: interactor, router: Router()),
            interactor: interactor
        )
    }

    @Test("Test The Options Offered Are All Of Them")
    func testTheOptionsOfferedAreAllOfThem() {
        let screen = makeScreen()

        #expect(screen.presenter.initialLogFillOptions == InitialLogFillOption.allCases)
        #expect(screen.presenter.adjustmentModes == ProgressionAdjustmentMode.allCases)
    }

    @Test("Test The Screen Shows What Is Stored")
    func testTheScreenShowsWhatIsStored() {
        var settings = WorkoutSettings(authorId: "user-1")
        settings.smartProgressionApplyInSession = true
        settings.smartProgressionInitialLogFill = .empty
        settings.smartProgressionAdjustmentMode = .repsFirst
        let screen = makeScreen(settings)

        #expect(screen.presenter.applyInSession)
        #expect(screen.presenter.initialLogFill == .empty)
        #expect(screen.presenter.adjustmentMode == .repsFirst)
    }

    @Test("Test Choosing How Sets Are Filled Is Saved")
    func testChoosingHowSetsAreFilledIsSaved() async {
        let screen = makeScreen()

        screen.presenter.initialLogFill = .previousValues
        await settleSettings()

        #expect(screen.interactor.savedSettings.last?.smartProgressionInitialLogFill == .previousValues)
    }

    /// Changing the fill option must not also flip whether progression applies mid-session — they
    /// are separate decisions sharing one document.
    @Test("Test Choosing One Option Leaves The Others Alone")
    func testChoosingOneOptionLeavesTheOthersAlone() async {
        var settings = WorkoutSettings(authorId: "user-1")
        settings.smartProgressionApplyInSession = true
        settings.smartProgressionAdjustmentMode = .repsFirst
        let screen = makeScreen(settings)

        screen.presenter.initialLogFill = .empty
        await settleSettings()

        let saved = screen.interactor.savedSettings.last
        #expect(saved?.smartProgressionInitialLogFill == .empty)
        #expect(saved?.smartProgressionApplyInSession == true)
        #expect(saved?.smartProgressionAdjustmentMode == .repsFirst)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: SmartProgressionSettingsDelegate())

        #expect(screen.interactor.trackedScreenEventNames == ["SmartProgressionSettingsView_Appear"])
    }

    /// All five workout-settings screens edit a copy of the one settings document and write the
    /// whole thing back, so a copy taken when the screen was built reverts anything saved
    /// elsewhere since. Change your rest timer, walk in here, pick an option, and the rest timer
    /// silently goes back — with nothing on screen to say it happened.
    @Test("Test Settings Changed Elsewhere Are Not Undone")
    func testSettingsChangedElsewhereAreNotUndone() async {
        let screen = makeScreen()

        // Saved from another screen after this presenter was built.
        screen.interactor.workoutSettings.defaultRestDurationSeconds = 240
        screen.presenter.onViewAppear(delegate: SmartProgressionSettingsDelegate())
        screen.presenter.applyInSession = true
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        #expect(screen.interactor.savedSettings.last?.defaultRestDurationSeconds == 240)
        #expect(screen.interactor.savedSettings.last?.smartProgressionApplyInSession == true)
    }
}

/// Which earlier workout the "last time" figures are taken from.
@MainActor
struct PrevWORefSettingsPresenterTests {

    private final class Router: PreviousWorkoutReferenceSettingsRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private struct Screen {
        let presenter: PrevWORefSettingsPresenter
        let interactor: SettingsInteractor
    }

    private func makeScreen(_ settings: WorkoutSettings = WorkoutSettings(authorId: "user-1")) -> Screen {
        let interactor = SettingsInteractor()
        interactor.workoutSettings = settings
        return Screen(
            presenter: PrevWORefSettingsPresenter(interactor: interactor, router: Router()),
            interactor: interactor
        )
    }

    @Test("Test Both References Are Offered")
    func testBothReferencesAreOffered() {
        let screen = makeScreen()

        #expect(screen.presenter.options == PreviousWorkoutReferenceOption.allCases)
        #expect(screen.presenter.previousWorkoutReference == .sameWorkout)
    }

    /// This decides which numbers a set is compared against while training, so it has to reach
    /// storage rather than only the radio button.
    @Test("Test Choosing A Reference Is Saved")
    func testChoosingAReferenceIsSaved() async {
        let screen = makeScreen()

        screen.presenter.previousWorkoutReference = .workoutsInMesocycle
        await settleSettings()

        #expect(screen.presenter.previousWorkoutReference == .workoutsInMesocycle)
        #expect(screen.interactor.savedSettings.last?.previousWorkoutReference == .workoutsInMesocycle)
    }

    @Test("Test Choosing A Reference Leaves The Other Settings Alone")
    func testChoosingAReferenceLeavesTheOtherSettingsAlone() async {
        var settings = WorkoutSettings(authorId: "user-1")
        settings.rirTracking = true
        settings.defaultRestDurationSeconds = 120
        let screen = makeScreen(settings)

        screen.presenter.previousWorkoutReference = .workoutsInMesocycle
        await settleSettings()

        let saved = screen.interactor.savedSettings.last
        #expect(saved?.rirTracking == true)
        #expect(saved?.defaultRestDurationSeconds == 120)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: PrevWORefSettingsDelegate())

        #expect(screen.interactor.trackedScreenEventNames == ["PreviousWorkoutReferenceSettingsView_Appear"])
    }
}

/// The exercise library, reached from the training settings.
@MainActor
struct ExercisesPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ExercisesInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
    }

    /// `showSimpleAlert` is restated as a requirement on this screen's own router protocol, so
    /// unlike on the equipment screens a double does see it. `showDevSettingsView` is not part of
    /// this protocol at all.
    private final class Router: ExercisesRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var openedExercises: [ExerciseModel] = []
        private(set) var shown: [String] = []

        func showCreateExerciseView() { shown.append("createExercise") }

        func showExerciseModelDetailView(delegate: ExerciseModelDetailDelegate) {
            openedExercises.append(delegate.exerciseModel)
        }

        func showSimpleAlert(title: String, subtitle: String?) { shown.append("alert") }
    }

    private func exercise(_ id: String) -> ExerciseModel {
        ExerciseModel(
            id: id,
            authorId: "user-1",
            name: "Squat",
            trackableMetrics: [.weight, .reps],
            type: .compoundLower,
            laterality: .bilateral,
            muscleGroups: [:],
            isBodyweight: false,
            rangeOfMotion: 1,
            stability: 1,
            bodyWeightContribution: 0,
            alternateNames: []
        )
    }

    /// The row tapped is the exercise opened — the detail screen reads its whole history from the
    /// exercise it is handed, so the wrong one would show someone else's numbers.
    @Test("Test Tapping An Exercise Opens That Exercise")
    func testTappingAnExerciseOpensThatExercise() {
        let router = Router()
        let presenter = ExercisesPresenter(interactor: Interactor(), router: router)

        presenter.onExercisePressed(exercise: exercise("squat"))

        #expect(router.openedExercises.map(\.id) == ["squat"])
        #expect(router.shown.isEmpty)
    }
}

/// The exercise assessment, which is a static explainer at this point and only reports itself.
@MainActor
struct ExerciseAssessmentPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ExerciseAssessmentInteractor { }

    private final class Router: ExerciseAssessmentRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    @Test("Test Appearing And Leaving Are Tracked Separately")
    func testAppearingAndLeavingAreTrackedSeparately() {
        let interactor = Interactor()
        let presenter = ExerciseAssessmentPresenter(interactor: interactor, router: Router())

        presenter.onViewAppear(delegate: ExerciseAssessmentDelegate())
        presenter.onViewDisappear(delegate: ExerciseAssessmentDelegate())

        #expect(interactor.trackedScreenEventNames == ["ExerciseAssessmentView_Appear"])
        #expect(interactor.trackedEventNames == ["ExerciseAssessmentView_Disappear"])
    }
}
