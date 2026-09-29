//
//  WorkoutTrackingSheetPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The sheet that picks which set-up of an exercise is being used — the cable-and-rope version of
/// a pushdown rather than the bar version.
///
/// Its risk is entirely in where the list of set-ups comes from. New sessions carry their own copy;
/// sessions logged before that was stored have to be matched back to the exercise library, which
/// may not have loaded yet. Getting that wrong shows an empty sheet or a spinner that never stops.
@MainActor
struct WorkoutEquipmentSheetPresenterTests {

    private final class Interactor: SpyGlobalInteractor, WorkoutExerciseEquipmentSheetInteractor {
        var userId: String? = "user-1"
        var workoutGymProfile: GymProfileModel?
        var allExercises: [ExerciseModel] = []
    }

    /// `WorkoutExerciseEquipmentSheetRouter` adds nothing to `GlobalRouter`, so the dismissals both
    /// buttons perform are extension methods that never reach here. The tests assert what the
    /// buttons hand back instead.
    private final class Router: WorkoutExerciseEquipmentSheetRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private struct Screen {
        let presenter: WorkoutExerciseEquipmentSheetPresenter
        let interactor: Interactor
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        return Screen(
            presenter: WorkoutExerciseEquipmentSheetPresenter(interactor: interactor, router: Router()),
            interactor: interactor
        )
    }

    private func variation(id: String) -> EquipmentVariation {
        EquipmentVariation(
            id: id,
            resistanceEquipment: [EquipmentRef(kind: .freeWeight, id: "dumbbells")],
            supportEquipment: [EquipmentRef(kind: .supportEquipment, id: "flat_bench")]
        )
    }

    private func exercise(
        templateId: String = "template-1",
        chosenVariationId: String? = nil,
        variations: [EquipmentVariation] = []
    ) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "exercise-1",
            authorId: "user-1",
            templateId: templateId,
            name: "Bench Press",
            trackingMode: .weightReps,
            index: 1,
            sets: [],
            chosenVariationId: chosenVariationId,
            equipmentVariations: variations
        )
    }

    private func exerciseModel(id: String, name: String, variations: [EquipmentVariation]) -> ExerciseModel {
        ExerciseModel(
            id: id,
            authorId: "user-1",
            name: name,
            trackableMetrics: [.weight, .reps],
            type: .compoundUpper,
            laterality: .bilateral,
            muscleGroups: [:],
            isBodyweight: false,
            equipmentVariations: variations,
            rangeOfMotion: 1,
            stability: 1,
            bodyWeightContribution: 0,
            alternateNames: []
        )
    }

    @Test("Test The Sessions Own Set Ups Are Listed")
    func testTheSessionsOwnSetUpsAreListed() async {
        let screen = makeScreen()

        await screen.presenter.loadVariations(
            exercise: exercise(variations: [variation(id: "v1"), variation(id: "v2")])
        )

        #expect(screen.presenter.variationItems.map(\.id) == ["v1", "v2"])
        #expect(screen.presenter.variationItems.map(\.name) == ["Variation 1", "Variation 2"])
        #expect(screen.presenter.isLoading == false)
        #expect(screen.presenter.loadError == nil)
    }

    /// Equipment is stored as a reference, not a label, so the sheet has to resolve each one
    /// against the catalog. A row reading "freeWeight:dumbbell" would be unreadable.
    @Test("Test Equipment Is Shown By Name Not By Reference")
    func testEquipmentIsShownByNameNotByReference() async {
        let screen = makeScreen()

        await screen.presenter.loadVariations(exercise: exercise(variations: [variation(id: "v1")]))

        let item = screen.presenter.variationItems.first
        #expect(item?.resistanceSummary == "Dumbbells")
        #expect(item?.supportSummary == "Flat Bench")
    }

    @Test("Test A Set Up With No Equipment Reads As None")
    func testASetUpWithNoEquipmentReadsAsNone() async {
        let screen = makeScreen()
        let bare = EquipmentVariation(id: "v1", resistanceEquipment: [], supportEquipment: [])

        await screen.presenter.loadVariations(exercise: exercise(variations: [bare]))

        #expect(screen.presenter.variationItems.first?.resistanceSummary == "None")
        #expect(screen.presenter.variationItems.first?.supportSummary == "None")
    }

    /// Opening the sheet on an exercise that has never had a set-up chosen lands on the first one,
    /// so pressing Done immediately records something rather than nothing.
    @Test("Test The First Set Up Is Selected When None Was Chosen")
    func testTheFirstSetUpIsSelectedWhenNoneWasChosen() async {
        let screen = makeScreen()

        await screen.presenter.loadVariations(
            exercise: exercise(variations: [variation(id: "v1"), variation(id: "v2")])
        )

        #expect(screen.presenter.chosenVariationId == "v1")
    }

    @Test("Test An Existing Choice Is Kept")
    func testAnExistingChoiceIsKept() async {
        let screen = makeScreen()

        await screen.presenter.loadVariations(
            exercise: exercise(chosenVariationId: "v2", variations: [variation(id: "v1"), variation(id: "v2")])
        )

        #expect(screen.presenter.chosenVariationId == "v2")
    }

    /// Sessions logged before set-ups were stored on the session have nothing to show, so the
    /// sheet falls back to the exercise library.
    @Test("Test An Old Session Falls Back To The Exercise Library")
    func testAnOldSessionFallsBackToTheExerciseLibrary() async {
        let screen = makeScreen()
        screen.interactor.allExercises = [
            exerciseModel(id: "template-1", name: "Bench Press", variations: [variation(id: "lib-1")])
        ]

        await screen.presenter.loadVariations(exercise: exercise())

        #expect(screen.presenter.variationItems.map(\.id) == ["lib-1"])
    }

    /// An exercise re-seeded under a new id leaves old sessions pointing at a template that no
    /// longer exists, so the name is the last way back to its set-ups.
    @Test("Test A Stale Template Id Is Matched By Name")
    func testAStaleTemplateIdIsMatchedByName() async {
        let screen = makeScreen()
        screen.interactor.allExercises = [
            exerciseModel(id: "system-bench-v2", name: "bench press", variations: [variation(id: "lib-1")])
        ]

        await screen.presenter.loadVariations(exercise: exercise(templateId: "gone"))

        #expect(screen.presenter.variationItems.map(\.id) == ["lib-1"])
    }

    /// Nothing to show is an explained empty sheet, not a spinner — a spinner that never stops is
    /// indistinguishable from a sheet still loading.
    @Test("Test An Exercise With No Set Ups Explains Itself")
    func testAnExerciseWithNoSetUpsExplainsItself() async {
        let screen = makeScreen()
        screen.interactor.allExercises = [
            exerciseModel(id: "template-1", name: "Bench Press", variations: [])
        ]

        await screen.presenter.loadVariations(exercise: exercise())

        #expect(screen.presenter.isLoading == false)
        #expect(screen.presenter.loadError != nil)
        #expect(screen.presenter.variationItems.isEmpty)
        #expect(screen.interactor.trackedEventNames.contains(
            "WorkoutExerciseEquipmentSheetView_LoadVariations_Fail"
        ))
    }

    @Test("Test Choosing A Set Up And Pressing Done Hands It Back")
    func testChoosingASetUpAndPressingDoneHandsItBack() async {
        let screen = makeScreen()
        await screen.presenter.loadVariations(
            exercise: exercise(variations: [variation(id: "v1"), variation(id: "v2")])
        )
        var selected: [String?] = []

        screen.presenter.onSelectVariation(id: "v2")
        screen.presenter.onDonePressed { selected.append($0) }

        #expect(selected == ["v2"])
    }

    /// Backing out changes nothing. Cancel only dismisses — a `GlobalRouter` extension this
    /// double cannot see — so what the test holds is that the choice made on screen was never
    /// handed anywhere, leaving the exercise on the set-up it arrived with.
    @Test("Test Cancelling Keeps The Choice On The Sheet")
    func testCancellingKeepsTheChoiceOnTheSheet() async {
        let screen = makeScreen()
        await screen.presenter.loadVariations(
            exercise: exercise(chosenVariationId: "v1", variations: [variation(id: "v1"), variation(id: "v2")])
        )

        screen.presenter.onSelectVariation(id: "v2")
        screen.presenter.onCancelPressed()

        #expect(screen.presenter.chosenVariationId == "v2")
    }
}

/// The warm-up sheet: the same set rows, filtered to the warm-up sets of one exercise.
///
/// It owns no logic of its own — the exercise arrives already bound — so what matters is that it
/// is recorded in analytics under its own name and that its dismissal is safe to call.
@MainActor
struct WarmupSetsPresenterTests {

    private final class Interactor: SpyGlobalInteractor, WarmupSetsInteractor { }

    /// `WarmupSetsRouter` adds nothing to `GlobalRouter`, so `dismissScreen()` is an extension
    /// method that dispatches statically and never reaches this double.
    private final class Router: WarmupSetsRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    @MainActor
    private final class Box {
        var value: WorkoutExerciseModel

        init(_ value: WorkoutExerciseModel) {
            self.value = value
        }

        var binding: Binding<WorkoutExerciseModel> {
            Binding(
                get: { MainActor.assumeIsolated { self.value } },
                set: { newValue in MainActor.assumeIsolated { self.value = newValue } }
            )
        }
    }

    private func exercise() -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "exercise-1",
            authorId: "user-1",
            templateId: "template-1",
            name: "Bench Press",
            trackingMode: .weightReps,
            index: 1,
            sets: []
        )
    }

    @Test("Test The Warmup Sheet Holds The Exercise It Was Opened With")
    func testTheWarmupSheetHoldsTheExerciseItWasOpenedWith() {
        let model = exercise()
        let presenter = WarmupSetsPresenter(
            interactor: Interactor(),
            router: Router(),
            exercise: model
        )

        #expect(presenter.exercise.id == model.id)
        #expect(presenter.exercise.templateId == model.templateId)
    }

    @Test("Test The Warmup Sheet Records Appearing And Disappearing")
    func testTheWarmupSheetRecordsAppearingAndDisappearing() {
        let interactor = Interactor()
        let presenter = WarmupSetsPresenter(interactor: interactor, router: Router(), exercise: exercise())
        let box = Box(exercise())
        let delegate = WarmupSetsDelegate(exercise: box.binding)

        presenter.onViewAppear(delegate: delegate)
        presenter.onViewDisappear(delegate: delegate)

        #expect(interactor.trackedScreenEventNames == ["WarmupSetsView_Appear"])
        #expect(interactor.trackedEventNames == ["WarmupSetsView_Disappear"])
    }

    /// Closing the sheet leaves the exercise exactly as it was — the sets were edited in place
    /// through the binding, so dismissal must not be a save or a revert.
    @Test("Test Dismissing The Warmup Sheet Changes Nothing")
    func testDismissingTheWarmupSheetChangesNothing() {
        let interactor = Interactor()
        let presenter = WarmupSetsPresenter(interactor: interactor, router: Router(), exercise: exercise())
        let before = presenter.exercise

        presenter.onDismissPressed()

        #expect(presenter.exercise == before)
        #expect(interactor.trackedEventNames.isEmpty)
    }
}

/// The picker for swapping one exercise for another mid-workout — the rack is taken, so something
/// else has to do.
///
/// A swap rewrites what the session says was trained, so the only thing that must hold is that the
/// exercise handed back is the one that was tapped.
@MainActor
struct SwapExercisePickerPresenterTests {

    private final class Interactor: SpyGlobalInteractor, SwapExercisePickerInteractor {
        var allExercises: [ExerciseModel] = []
    }

    /// `SwapExercisePickerRouter` adds nothing to `GlobalRouter`, so the dismissal both paths
    /// perform is an extension method that never reaches this double.
    private final class Router: SwapExercisePickerRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private func exerciseModel(id: String, name: String) -> ExerciseModel {
        ExerciseModel(
            id: id,
            authorId: "user-1",
            name: name,
            trackableMetrics: [.weight, .reps],
            type: .compoundUpper,
            laterality: .bilateral,
            muscleGroups: [:],
            isBodyweight: false,
            rangeOfMotion: 1,
            stability: 1,
            bodyWeightContribution: 0,
            alternateNames: []
        )
    }

    private func makePresenter(
        exercises: [ExerciseModel],
        onSelect: @escaping (ExerciseModel) -> Void = { _ in }
    ) -> SwapExercisePickerPresenter {
        let interactor = Interactor()
        interactor.allExercises = exercises
        return SwapExercisePickerPresenter(interactor: interactor, router: Router(), onSelect: onSelect)
    }

    @Test("Test An Empty Search Shows Everything")
    func testAnEmptySearchShowsEverything() {
        let presenter = makePresenter(exercises: [
            exerciseModel(id: "1", name: "Bench Press"),
            exerciseModel(id: "2", name: "Incline Press")
        ])

        #expect(presenter.filteredExercises.count == 2)
    }

    /// Searching is by what the user is looking at, not by how it is capitalised, and matches
    /// anywhere in the name so "press" finds the inclines too.
    @Test("Test Searching Matches Anywhere In The Name Ignoring Case")
    func testSearchingMatchesAnywhereInTheNameIgnoringCase() {
        let presenter = makePresenter(exercises: [
            exerciseModel(id: "1", name: "Bench Press"),
            exerciseModel(id: "2", name: "Incline Press"),
            exerciseModel(id: "3", name: "Barbell Row")
        ])

        presenter.searchText = "press"

        #expect(presenter.filteredExercises.map(\.id) == ["1", "2"])
    }

    @Test("Test A Search That Matches Nothing Shows Nothing")
    func testASearchThatMatchesNothingShowsNothing() {
        let presenter = makePresenter(exercises: [exerciseModel(id: "1", name: "Bench Press")])

        presenter.searchText = "deadlift"

        #expect(presenter.filteredExercises.isEmpty)
    }

    /// The exercise tapped is the exercise the session gets. Handing back the wrong one logs the
    /// workout against a movement that was never performed.
    @Test("Test The Tapped Exercise Is Handed Back")
    func testTheTappedExerciseIsHandedBack() {
        var selected: [String] = []
        let presenter = makePresenter(
            exercises: [exerciseModel(id: "1", name: "Bench Press")],
            onSelect: { selected.append($0.id) }
        )

        presenter.onExerciseSelected(exerciseModel(id: "2", name: "Incline Press"))

        #expect(selected == ["2"])
    }

    /// Backing out of the picker swaps nothing.
    @Test("Test Dismissing The Picker Swaps Nothing")
    func testDismissingThePickerSwapsNothing() {
        var selected: [String] = []
        let presenter = makePresenter(
            exercises: [exerciseModel(id: "1", name: "Bench Press")],
            onSelect: { selected.append($0.id) }
        )

        presenter.onDismissPressed()

        #expect(selected.isEmpty)
    }
}

/// The exercise card in the tracker — the header, the set list and the menu behind it.
///
/// The view drives almost everything through the delegate; the presenter's one piece of state is
/// the note kept on the exercise's settings screen, which the header now shows.
@MainActor
struct ExerciseTrackerPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ExerciseTrackerInteractor {
        var notes: [String: String] = [:]

        func exerciseNote(for exerciseId: String) -> String? {
            notes[exerciseId]
        }
    }

    private final class Router: ExerciseTrackerRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showWorkoutNotesView(delegate: WorkoutNotesDelegate) { }
    }

    private func exercise(templateId: String = "template-1") -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "e1",
            authorId: "author-1",
            templateId: templateId,
            name: "Bench Press",
            trackingMode: .weightReps,
            index: 1,
            sets: []
        )
    }

    @Test("Test Building An Exercise Card Has No Side Effects")
    func testBuildingAnExerciseCardHasNoSideEffects() {
        let interactor = Interactor()

        _ = ExerciseTrackerPresenter(interactor: interactor, router: Router())

        #expect(interactor.trackedEventNames.isEmpty)
        #expect(interactor.trackedScreenEventNames.isEmpty)
        #expect(interactor.playedHaptics.isEmpty)
    }

    // MARK: - The exercise note

    /// The state every user is in until they write one: the header draws exactly what it drew
    /// before.
    @Test("Test An Exercise With No Note Shows Nothing")
    func testAnExerciseWithNoNoteShowsNothing() {
        let presenter = ExerciseTrackerPresenter(interactor: Interactor(), router: Router())

        #expect(presenter.note(for: exercise()) == nil)
    }

    /// The note the settings screen saved, readable while the lift is being done rather than only
    /// back on the screen that wrote it.
    @Test("Test A Saved Note Is Shown On The Exercise")
    func testASavedNoteIsShownOnTheExercise() {
        let interactor = Interactor()
        interactor.notes = ["template-1": "Bench at 30 degrees"]
        let presenter = ExerciseTrackerPresenter(interactor: interactor, router: Router())

        #expect(presenter.note(for: exercise()) == "Bench at 30 degrees")
    }

    /// A note belongs to an exercise template, not to whichever card is on screen.
    @Test("Test Another Exercises Note Is Not Shown")
    func testAnotherExercisesNoteIsNotShown() {
        let interactor = Interactor()
        interactor.notes = ["template-2": "Bench at 30 degrees"]
        let presenter = ExerciseTrackerPresenter(interactor: interactor, router: Router())

        #expect(presenter.note(for: exercise()) == nil)
    }

    /// A note saved as whitespace is a note the user cleared, and must not push a blank line into
    /// the header.
    @Test("Test A Whitespace Note Counts As No Note")
    func testAWhitespaceNoteCountsAsNoNote() {
        let interactor = Interactor()
        interactor.notes = ["template-1": "  \n "]
        let presenter = ExerciseTrackerPresenter(interactor: interactor, router: Router())

        #expect(presenter.note(for: exercise()) == nil)
    }

    @Test("Test A Note Is Trimmed")
    func testANoteIsTrimmed() {
        let interactor = Interactor()
        interactor.notes = ["template-1": "  Go slow on the eccentric\n"]
        let presenter = ExerciseTrackerPresenter(interactor: interactor, router: Router())

        #expect(presenter.note(for: exercise()) == "Go slow on the eccentric")
    }
}

/// The notes sheet on a workout — free text saved against the session.
///
/// The text is edited straight through a binding the view owns, so the presenter's only job is to
/// close the sheet without touching what was typed.
@MainActor
struct WorkoutNotesPresenterTests {

    private final class Interactor: WorkoutNotesInteractor { }

    /// `WorkoutNotesRouter` adds nothing to `GlobalRouter`, so `dismissScreen()` is an extension
    /// method and never reaches this double. What the test can hold is that closing the sheet does
    /// not disturb the notes.
    private final class Router: WorkoutNotesRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    @MainActor
    private final class Box {
        var value: String

        init(_ value: String) {
            self.value = value
        }

        var binding: Binding<String> {
            Binding(
                get: { MainActor.assumeIsolated { self.value } },
                set: { newValue in MainActor.assumeIsolated { self.value = newValue } }
            )
        }
    }

    /// Closing the sheet is not a discard — what was typed stays typed, and saving is the view's
    /// own `onSave`, run separately.
    @Test("Test Closing The Notes Sheet Keeps What Was Typed")
    func testClosingTheNotesSheetKeepsWhatWasTyped() {
        let presenter = WorkoutNotesPresenter(interactor: Interactor(), router: Router())
        let box = Box("Felt strong, bumped the top set.")
        let delegate = WorkoutNotesDelegate(notes: box.binding, onSave: { })

        presenter.onDismissPressed()

        #expect(box.value == "Felt strong, bumped the top set.")
        #expect(delegate.notes.wrappedValue == "Felt strong, bumped the top set.")
    }
}
