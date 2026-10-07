//
//  SetTargetPlanPresenterTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

@MainActor
private final class PlanInteractor: SpyGlobalInteractor, SetTargetInteractor, ExercisesPickerInteractor {
    var workoutSettings = WorkoutSettings(authorId: "user-1")
    var allExercises: [ExerciseModel] = []
}

@MainActor
private final class PlanRouter: SetTargetRouter, ExercisesPickerRouter {
    let router: AnyRouter = TestRouting.anyRouter
    private(set) var details: [SetPlanDetailDelegate] = []
    private(set) var pickers: [ExercisesPickerDelegate] = []
    private(set) var variations: [MicrocycleVariationsDelegate] = []

    func showSetPlanDetailView(delegate: SetPlanDetailDelegate) { details.append(delegate) }
    func showExercisesPickerView(delegate: ExercisesPickerDelegate) { pickers.append(delegate) }
    func showMicrocycleVariationsView(delegate: MicrocycleVariationsDelegate) { variations.append(delegate) }
    func showConfirmationDialog(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
}

@MainActor
private final class PlanExerciseBox {
    var value: WorkoutTemplateExercise

    init(_ setTargets: [SetTarget]) {
        var exercise = WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)
        exercise.setTargets = setTargets
        value = exercise
    }

    var binding: Binding<WorkoutTemplateExercise> {
        Binding(
            get: { MainActor.assumeIsolated { self.value } },
            set: { newValue in MainActor.assumeIsolated { self.value = newValue } }
        )
    }
}

/// The template editor with Workout Settings › Set Plan: the kind and plan under each set, and the
/// sheet that edits one set's plan.
@MainActor
struct SetTargetPlanPresenterTests {

    private struct Screen {
        let editor: SetTargetPresenter
        let interactor: PlanInteractor
        let router: PlanRouter
        let box: PlanExerciseBox
    }

    private func makeScreen(plansSets: Bool = true, _ setTargets: [SetTarget] = [SetTarget(id: "s1", setNumber: 1, minReps: 8, maxReps: 8)]) -> Screen {
        let interactor = PlanInteractor()
        interactor.workoutSettings.setPlanning = plansSets
        let router = PlanRouter()
        let box = PlanExerciseBox(setTargets)
        let editor = SetTargetPresenter(interactor: interactor, router: router, delegate: SetTargetDelegate(exercise: box.binding, scope: .template))
        return Screen(editor: editor, interactor: interactor, router: router, box: box)
    }

    /// Opens the first set's plan the way the row does, and returns the sheet's presenter.
    private func openDetail(_ screen: Screen, set index: Int = 0) throws -> SetPlanDetailPresenter {
        screen.editor.onSetPlanPressed(screen.editor.workingExercise.setTargets[index])
        let delegate = try #require(screen.router.details.last)
        return SetPlanDetailPresenter(interactor: screen.interactor, router: screen.router, delegate: delegate)
    }

    // MARK: - The editor

    @Test("Test The Editor Follows The Switch")
    func testTheEditorFollowsTheSwitch() {
        #expect(makeScreen(plansSets: true).editor.plansSets)
        #expect(!makeScreen(plansSets: false).editor.plansSets)
    }

    @Test("Test A Row Names Its Set And Kind For VoiceOver")
    func testRowAccessibility() {
        let screen = makeScreen(plansSets: true, [SetTarget(setNumber: 3, setType: .drop, dropCount: 2)])
        let target = screen.editor.workingExercise.setTargets[0]

        #expect(screen.editor.planAccessibilityLabel(for: target) == "Set 3, set type, Drop set")
        #expect(screen.editor.planChip(for: target) == "Drop set")
        #expect(screen.editor.planSummary(for: target) == "−20% ×2 to failure")
    }

    @Test("Test Tapping A Row Opens That Set's Plan")
    func testTappingARowOpensThePlan() {
        let screen = makeScreen()

        screen.editor.onSetPlanPressed(screen.editor.workingExercise.setTargets[0])

        #expect(screen.router.details.map(\.setTarget.id) == ["s1"])
    }

    // MARK: - The detail, round trips

    @Test("Test Choosing Drop Set Starts With Two Drops And Saves Each Field")
    func testDropRoundTrip() throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.setType = .drop
        #expect(detail.dropCount == 2)
        #expect(screen.editor.hasUnsavedChanges)

        detail.dropCount = 3
        detail.onDropStepPressed(30)
        detail.dropReps = 6
        screen.editor.onSavePressed()

        let saved = screen.box.value.setTargets[0]
        #expect(saved.setType == .drop)
        #expect(saved.dropCount == 3)
        #expect(saved.dropStepPercent == 30)
        #expect(saved.dropReps == 6)
        #expect(saved.minReps == 8 && saved.maxReps == 8)
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["selection", "selection"])
    }

    @Test("Test Clearing The Drop Reps Goes Back To Failure")
    func testClearingDropReps() throws {
        let screen = makeScreen(plansSets: true, [SetTarget(setNumber: 1, setType: .drop, dropCount: 2, dropReps: 6)])
        let detail = try openDetail(screen)

        detail.dropReps = nil

        #expect(screen.editor.workingExercise.setTargets[0].dropReps == nil)
    }

    @Test("Test Mini-Sets Are Saved For Each Kind That Takes Them", arguments: [SetTargetSetType.myo, .restPause, .cluster])
    func testMiniSetRoundTrip(kind: SetTargetSetType) throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.setType = kind
        #expect(detail.miniSetCount == 3)
        #expect(detail.showsMiniSets && !detail.showsDrops && !detail.showsAMRAPTarget)
        detail.miniSetCount = 5
        screen.editor.onSavePressed()

        #expect(screen.box.value.setTargets[0].setType == kind)
        #expect(screen.box.value.setTargets[0].miniSetCount == 5)
    }

    @Test("Test An AMRAP Target Starts From The Set's Reps And Is Saved")
    func testAMRAPRoundTrip() throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.setType = .amrap
        #expect(detail.amrapTargetReps == 8)
        detail.amrapTargetReps = 10
        screen.editor.onSavePressed()

        #expect(screen.box.value.setTargets[0].setType == .amrap)
        #expect(screen.box.value.setTargets[0].amrapTargetReps == 10)
    }

    // MARK: WP-P2

    @Test("Test Partials Start To Failure And Save Their Reps")
    func testPartialsRoundTrip() throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.setType = .partials
        #expect(detail.showsPartialReps && !detail.showsHoldSeconds && !detail.showsDrops)
        #expect(detail.partialReps == nil)
        #expect(detail.partialRepsChoices == [nil] + Array(1...10).map(Optional.some))
        #expect(detail.partialRepsTitle(nil) == "To failure")
        #expect(detail.partialRepsTitle(5) == "5 reps")
        detail.partialReps = 5
        screen.editor.onSavePressed()

        #expect(screen.box.value.setTargets[0].setType == .partials)
        #expect(screen.box.value.setTargets[0].partialReps == 5)
    }

    @Test("Test A Stretch Or Hold Starts At 30 Seconds And Saves Its Time", arguments: [SetTargetSetType.stretch, .hold])
    func testHoldSecondsRoundTrip(kind: SetTargetSetType) throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.setType = kind
        #expect(detail.showsHoldSeconds && !detail.showsPartialReps)
        #expect(detail.holdSeconds == 30)
        #expect(detail.holdSecondsChoices == [15, 20, 30, 45, 60])
        #expect(detail.holdSecondsTitle(45) == "45 s")
        detail.holdSeconds = 45
        screen.editor.onSavePressed()

        #expect(screen.box.value.setTargets[0].setType == kind)
        #expect(screen.box.value.setTargets[0].holdSeconds == 45)
    }

    /// An imported plan's 40 s hold is not one of the choices, but still shows as chosen.
    @Test("Test A Hold Time Outside The Choices Is Offered Too")
    func testUnlistedHoldSeconds() throws {
        let screen = makeScreen(plansSets: true, [SetTarget(setNumber: 1, setType: .hold, holdSeconds: 40)])
        let detail = try openDetail(screen)

        #expect(detail.holdSecondsChoices == [15, 20, 30, 40, 45, 60])
    }

    @Test("Test A Typed Target That Is Not A Count Is No Target")
    func testBadTarget() throws {
        let screen = makeScreen(plansSets: true, [SetTarget(setNumber: 1, setType: .amrap, amrapTargetReps: 8)])
        let detail = try openDetail(screen)

        detail.amrapTargetReps = 0
        #expect(detail.amrapTargetReps == nil)
        detail.amrapTargetReps = 9.6
        #expect(detail.amrapTargetReps == 10)
        detail.amrapTargetReps = .infinity
        #expect(detail.amrapTargetReps == nil)
    }

    /// Templates saved before AMRAP existed called it a failure set.
    @Test("Test A Legacy Failure Set Shows As AMRAP And Is Written As AMRAP On Edit")
    func testFailureBecomesAMRAP() throws {
        let screen = makeScreen(plansSets: true, [SetTarget(setNumber: 1, setType: .failure)])
        let detail = try openDetail(screen)

        #expect(detail.setType == .amrap)
        #expect(!screen.editor.hasUnsavedChanges)

        detail.amrapTargetReps = 8
        #expect(screen.editor.workingExercise.setTargets[0].setType == .amrap)
    }

    @Test("Test Picking The Kind Already Chosen Changes Nothing")
    func testSameKind() throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.setType = .standard

        #expect(!screen.editor.hasUnsavedChanges)
        #expect(screen.interactor.playedHaptics.isEmpty)
    }

    @Test("Test Cancelling After A Plan Edit Asks First")
    func testCancelAfterPlanEdit() throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.setType = .drop
        screen.editor.onClosePressed()

        #expect(screen.box.value.setTargets[0].setType == .standard)
        #expect(screen.editor.hasUnsavedChanges)
    }

    @Test("Test The Sheet Names Its Set And Tracks Its Appearance")
    func testSheetTitleAndAppearance() throws {
        let screen = makeScreen()
        let detail = try openDetail(screen)

        detail.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["SetPlanDetailView_Appear"])
        #expect(detail.title == "Set 1")
        #expect(detail.setTypeAccessibilityLabel == "Set 1, set type")
    }
}

// MARK: - WP-P3: the exercise's plan

extension SetTargetPlanPresenterTests {

    private var library: [ExerciseModel] { Array(ExerciseModel.mocks.prefix(4)) }

    @Test("Test Warm-ups Are Automatic, None Or A Count, And Saved", arguments: [nil, 0, 4] as [Int?])
    func testWarmups(count: Int?) {
        let screen = makeScreen()
        #expect(screen.editor.warmupSetChoices == [nil, 0, 1, 2, 3, 4])
        #expect(screen.editor.warmupSetTitle(nil) == "Automatic")
        #expect(screen.editor.warmupSetTitle(3) == "3")

        screen.editor.warmupSetCount = count
        screen.editor.onSavePressed()

        #expect(screen.box.value.warmupSetCount == count)
    }

    @Test("Test Rest Is Automatic Or A Chosen Time, And Saved")
    func testRest() {
        let screen = makeScreen()
        #expect(screen.editor.restTitle(nil) == "Automatic")
        #expect(screen.editor.restTitle(90) == "1:30")
        #expect(screen.editor.restSecondsChoices.count == 41)

        screen.editor.restSeconds = 90
        #expect(screen.editor.hasUnsavedChanges)
        screen.editor.onSavePressed()

        #expect(screen.box.value.restSeconds == 90)
    }

    @Test("Test Notes Are Trimmed On Save And Blank Notes Are None")
    func testNotes() {
        let screen = makeScreen()
        screen.editor.notes = "  Pause at the bottom \n"
        screen.editor.onSavePressed()
        #expect(screen.box.value.notes == "Pause at the bottom")

        let blank = makeScreen()
        blank.editor.notes = "   "
        blank.editor.onSavePressed()
        #expect(blank.box.value.notes == nil)
    }

    @Test("Test A Web Address Is Saved As The Link")
    func testLinkAccepted() {
        let screen = makeScreen()

        screen.editor.linkText = " https://youtu.be/abc "
        #expect(screen.editor.linkIsValid)
        screen.editor.onSavePressed()

        #expect(screen.box.value.linkURL == "https://youtu.be/abc")
        #expect(!screen.editor.showsLinkError)
    }

    @Test("Test Anything Else Is Refused With An Error And Nothing Saved")
    func testLinkRejected() {
        let screen = makeScreen()

        screen.editor.linkText = "youtube.com/abc"
        #expect(screen.editor.hasUnsavedChanges)
        #expect(!screen.editor.showsLinkError)
        screen.editor.onLinkSubmitted()
        #expect(screen.editor.showsLinkError)

        screen.editor.onSavePressed()
        #expect(screen.box.value.linkURL == nil)
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["error"])

        screen.editor.linkText = "https://youtube.com/abc"
        #expect(!screen.editor.showsLinkError)
    }

    @Test("Test Clearing The Link Removes It")
    func testLinkCleared() {
        let screen = makeScreen()
        screen.box.value.linkURL = "https://example.com"
        let editor = SetTargetPresenter(interactor: screen.interactor, router: screen.router, delegate: SetTargetDelegate(exercise: screen.box.binding, scope: .template))
        #expect(editor.linkText == "https://example.com")

        editor.linkText = ""
        editor.onSavePressed()

        #expect(screen.box.value.linkURL == nil)
    }

    @Test("Test Substitutions Are Added From The Picker, Never The Exercise Itself, And Removed")
    func testSubstitutions() throws {
        let screen = makeScreen()
        screen.interactor.allExercises = library
        let own = screen.editor.workingExercise.exercise
        let others = library.filter { $0.id != own.id }

        screen.editor.onAddSubstitutionPressed()
        let picker = try #require(screen.router.pickers.last)
        #expect(picker.excludedExerciseIds == [own.id])
        picker.addedExercises.wrappedValue += [others[0], own, others[1]].map { WorkoutTemplateExercise(exercise: $0, setRestTimers: false) }

        #expect(screen.editor.substitutes.map(\.id) == [others[0].id, others[1].id])

        // Reopened, the chosen ones come back ticked and are not added twice.
        screen.editor.onAddSubstitutionPressed()
        let again = try #require(screen.router.pickers.last)
        #expect(again.addedExercises.wrappedValue.map(\.exercise.id) == [others[0].id, others[1].id])
        again.addedExercises.wrappedValue += [WorkoutTemplateExercise(exercise: others[0], setRestTimers: false)]
        #expect(screen.editor.workingExercise.substituteExerciseIds == [others[0].id, others[1].id])

        screen.editor.onRemoveSubstitutionPressed(others[0])
        screen.editor.onSavePressed()
        #expect(screen.box.value.substituteExerciseIds == [others[1].id])
    }

    @Test("Test The Picker Will Not Tick An Excluded Exercise")
    func testPickerExcludes() {
        let excluded = library[0]
        let picker = ExercisesPickerPresenter(
            interactor: PlanInteractor(),
            router: PlanRouter(),
            delegate: ExercisesPickerDelegate(addedExercises: .constant([]), excludedExerciseIds: [excluded.id])
        )

        picker.onExercisePressed(exercise: excluded)
        picker.onExercisePressed(exercise: library[1])

        #expect(picker.workingExercises.map(\.exercise.id) == [library[1].id])
    }

    @Test("Test The Plan Is Offered For A Template Only, And A Week Edits Its Targets Alone")
    func testScopes() {
        let box = PlanExerciseBox([SetTarget(setNumber: 1)])
        func editor(_ scope: SetTargetScope) -> SetTargetPresenter {
            SetTargetPresenter(interactor: PlanInteractor(), router: PlanRouter(), delegate: SetTargetDelegate(exercise: box.binding, scope: scope))
        }

        #expect(editor(.template).showsPlan && editor(.template).showsRestTimers)
        #expect(!editor(.session).showsPlan && editor(.session).showsRestTimers)
        #expect(!editor(.week(3)).showsPlan && !editor(.week(3)).showsRestTimers)
        #expect(editor(.session).title == "Targets")
        #expect(editor(.week(3)).title == "From week 3")
    }

    @Test("Test Varies By Week Opens The Variations And Their Changes Are Saved")
    func testVariesByWeek() throws {
        let screen = makeScreen()
        #expect(screen.editor.variationSummary == "Same every week")

        screen.editor.onVariesByWeekPressed()
        let delegate = try #require(screen.router.variations.last)
        delegate.onChange([MicrocycleSetTargets(fromMicrocycle: 2, setTargets: [SetTarget(setNumber: 1), SetTarget(setNumber: 2)])])

        #expect(screen.editor.variationSummary == "Week 1: 1 set · From week 2: 2 sets")
        screen.editor.onSavePressed()
        #expect(screen.box.value.setTargetsByMicrocycle.map(\.fromMicrocycle) == [2])
    }
}
