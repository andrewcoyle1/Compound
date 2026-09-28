//
//  CreateExerciseEquipmentPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

// MARK: - Shared scaffolding

/// A mutable value reachable through a `Binding`. `Binding`'s accessors are `@Sendable`, so the
/// box has to be main-actor isolated and reached through `assumeIsolated`.
@MainActor
private final class EquipmentRefBox {
    var value: [EquipmentRef] = []
    var binding: Binding<[EquipmentRef]> {
        Binding(
            get: { MainActor.assumeIsolated { self.value } },
            set: { newValue in MainActor.assumeIsolated { self.value = newValue } }
        )
    }
}

/// Stand-ins for the equipment catalog, one per kind the equipment step sorts on, so the tests do
/// not depend on which barbell happens to come first in the real catalog.
private struct FlowResistanceEquipment: GymEquipmentItem {
    static var kind: EquipmentKind { .freeWeight }
    let id: String
    let name: String
    var imageName: String? { nil }
    var description: String? { nil }
    var isActive: Bool { true }
}

private struct FlowSupportEquipment: GymEquipmentItem {
    static var kind: EquipmentKind { .supportEquipment }
    let id: String
    let name: String
    var imageName: String? { nil }
    var description: String? { nil }
    var isActive: Bool { true }
}

private struct FlowAccessoryEquipment: GymEquipmentItem {
    static var kind: EquipmentKind { .accessoryEquipment }
    let id: String
    let name: String
    var imageName: String? { nil }
    var description: String? { nil }
    var isActive: Bool { true }
}

private let dumbbell = AnyEquipment(FlowResistanceEquipment(id: "dumbbell", name: "Dumbbell"))
private let barbell = AnyEquipment(FlowResistanceEquipment(id: "barbell", name: "Barbell"))
private let bench = AnyEquipment(FlowSupportEquipment(id: "bench", name: "Flat Bench"))
private let straps = AnyEquipment(FlowAccessoryEquipment(id: "straps", name: "Lifting Straps"))
private let flowCatalog: [AnyEquipment] = [dumbbell, barbell, bench, straps]

// MARK: - Exercise Equipment

/// Step three: the equipment the exercise can be performed with, as one or more variations.
///
/// A variation is resistance plus optional support, and the screen holds several so one exercise
/// can cover a barbell and a dumbbell version. The risks are the gate (a loaded exercise with no
/// resistance is meaningless), the picker bindings pointing at the variation the user actually
/// tapped, and the whole draft surviving into the next step.
@MainActor
struct ExerciseEquipmentPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ExerciseEquipmentInteractor {
        var allEquipmentTypes: [AnyEquipment] = flowCatalog
    }

    private final class Router: ExerciseEquipmentRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var pickerDelegates: [EquipmentPickerDelegate] = []
        private(set) var finalDelegates: [FinalExerciseDetailsDelegate] = []

        func showEquipmentPickerView(delegate: EquipmentPickerDelegate) {
            pickerDelegates.append(delegate)
        }

        func showFinalExerciseDetailsView(delegate: FinalExerciseDetailsDelegate) {
            finalDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: ExerciseEquipmentPresenter
        let interactor: Interactor
        let router: Router
    }

    /// Appearing is what builds the name index the subtitles read, so every screen starts there.
    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        let presenter = ExerciseEquipmentPresenter(interactor: interactor, router: router)
        presenter.onViewAppear()
        return Screen(presenter: presenter, interactor: interactor, router: router)
    }

    private func delegate() -> ExerciseEquipmentDelegate {
        ExerciseEquipmentDelegate(
            name: "Bench Press",
            trackableMetricA: .reps,
            trackableMetricB: .weight,
            exerciseType: .compoundUpper,
            laterality: .bilateral,
            muscleGroups: [.chest: .primary]
        )
    }

    /// Support equipment assists a movement but does not load it, so a bench on its own is not an
    /// exercise anyone can be asked to log a weight against.
    @Test("Test Continuing Needs Resistance Or The Bodyweight Toggle")
    func testContinuingNeedsResistanceOrTheBodyweightToggle() {
        let fresh = makeScreen()
        #expect(!fresh.presenter.canContinue)

        let supportOnly = makeScreen()
        supportOnly.presenter.variations[0].supportEquipment = [bench.ref]
        #expect(!supportOnly.presenter.canContinue)

        let bodyweight = makeScreen()
        bodyweight.presenter.bodyweightExercise = true
        #expect(bodyweight.presenter.canContinue)
    }

    /// The resistance may sit on any variation, not only the first.
    @Test("Test A Later Variation With Resistance Is Enough")
    func testALaterVariationWithResistanceIsEnough() {
        let screen = makeScreen()
        screen.presenter.onAddVariationPressed()
        screen.presenter.variations[1].resistanceEquipment = [barbell.ref]
        #expect(screen.presenter.canContinue)
    }

    @Test("Test Variations Are Numbered From One")
    func testVariationsAreNumberedFromOne() {
        let screen = makeScreen()
        screen.presenter.onAddVariationPressed()
        #expect(screen.presenter.variations.count == 2)
        #expect(screen.presenter.variationName(for: 0) == "Variation 1")
        #expect(screen.presenter.variationName(for: 1) == "Variation 2")
    }

    @Test("Test Deleting A Variation Leaves The Others Alone")
    func testDeletingAVariationLeavesTheOthersAlone() {
        let screen = makeScreen()
        screen.presenter.variations[0].resistanceEquipment = [barbell.ref]
        screen.presenter.onAddVariationPressed()
        screen.presenter.onDeleteVariationPressed(id: screen.presenter.variations[1].id)
        #expect(screen.presenter.variations.count == 1)
        #expect(screen.presenter.variations[0].resistanceEquipment == [barbell.ref])
    }

    /// There is always at least one variation to fill in: deleting the last would leave the screen
    /// with nothing to show and no way to add anything back.
    @Test("Test The Last Variation Cannot Be Deleted")
    func testTheLastVariationCannotBeDeleted() {
        let screen = makeScreen()
        screen.presenter.onDeleteVariationPressed(id: screen.presenter.variations[0].id)
        #expect(screen.presenter.variations.count == 1)
    }

    /// The two rows offer opposite halves of the catalog: anything that assists rather than loads
    /// belongs under Support, and everything else under Resistance.
    @Test("Test The Two Pickers Offer Opposite Halves Of The Catalog")
    func testTheTwoPickersOfferOppositeHalvesOfTheCatalog() {
        let screen = makeScreen()
        let variationId = screen.presenter.variations[0].id
        screen.presenter.onAddResistancePressed(variationId: variationId)
        screen.presenter.onAddSupportPressed(variationId: variationId)
        #expect(screen.router.pickerDelegates.first?.headerTitle == "Resistance Equipment")
        #expect(screen.router.pickerDelegates.first?.items.map(\.id) == [dumbbell.id, barbell.id])
        #expect(screen.router.pickerDelegates.last?.headerTitle == "Support Equipment")
        #expect(screen.router.pickerDelegates.last?.items.map(\.id) == [bench.id, straps.id])
    }

    /// Several variations are open at once, so the picker has to write into the one whose Add
    /// button was tapped rather than the first.
    @Test("Test The Picker Writes Into The Variation That Was Tapped")
    func testThePickerWritesIntoTheVariationThatWasTapped() {
        let screen = makeScreen()
        screen.presenter.onAddVariationPressed()
        screen.presenter.onAddResistancePressed(variationId: screen.presenter.variations[1].id)
        screen.router.pickerDelegates.first?.chosenItem.wrappedValue = [dumbbell.ref]
        #expect(screen.presenter.variations[0].resistanceEquipment.isEmpty)
        #expect(screen.presenter.variations[1].resistanceEquipment == [dumbbell.ref])
    }

    @Test("Test An Unknown Variation Opens No Picker")
    func testAnUnknownVariationOpensNoPicker() {
        let screen = makeScreen()
        screen.presenter.onAddResistancePressed(variationId: "gone")
        screen.presenter.onAddSupportPressed(variationId: "gone")
        #expect(screen.router.pickerDelegates.isEmpty)
    }

    /// An empty row explains what goes in it; a filled one lists what was chosen by name, not by
    /// the raw identifier stored against it.
    @Test("Test The Rows Read As Prompts Until Equipment Is Chosen")
    func testTheRowsReadAsPromptsUntilEquipmentIsChosen() {
        let screen = makeScreen()
        let empty = screen.presenter.variations[0]
        #expect(screen.presenter.resistanceSubtitle(for: empty) == "Equipment that adds load to the exercise")
        #expect(screen.presenter.supportSubtitle(for: empty) == "Equipment that assists, stabilizes, or makes the movement possible")

        screen.presenter.variations[0].resistanceEquipment = [barbell.ref, dumbbell.ref]
        screen.presenter.variations[0].supportEquipment = [bench.ref]
        let filled = screen.presenter.variations[0]
        #expect(screen.presenter.resistanceSubtitle(for: filled) == "Barbell, Dumbbell")
        #expect(screen.presenter.supportSubtitle(for: filled) == "Flat Bench")
    }

    @Test("Test The Variations And Everything Before Them Reach The Final Step")
    func testTheVariationsAndEverythingBeforeThemReachTheFinalStep() {
        let screen = makeScreen()
        screen.presenter.variations[0].resistanceEquipment = [barbell.ref]
        screen.presenter.variations[0].supportEquipment = [bench.ref]
        screen.presenter.onNextPressed(delegate: delegate())
        let passed = screen.router.finalDelegates.first
        #expect(passed?.name == "Bench Press")
        #expect(passed?.trackableMetricA == .reps)
        #expect(passed?.trackableMetricB == .weight)
        #expect(passed?.exerciseType == .compoundUpper)
        #expect(passed?.laterality == .bilateral)
        #expect(passed?.targetMuscles == [.chest: .primary])
        #expect(passed?.isBodyweight == false)
        #expect(passed?.equipmentVariations.first?.resistanceEquipment == [barbell.ref])
        #expect(passed?.equipmentVariations.first?.supportEquipment == [bench.ref])
    }

    /// The toggle hid the variation rows but their drafts still travelled, so a bodyweight
    /// exercise could be saved with whatever equipment had been picked before the toggle.
    @Test("Test The Bodyweight Flag Reaches The Final Step Without The Hidden Variations")
    func testTheBodyweightFlagReachesTheFinalStep() {
        let screen = makeScreen()
        screen.presenter.variations[0].resistanceEquipment = [barbell.ref]
        screen.presenter.bodyweightExercise = true
        screen.presenter.onNextPressed(delegate: delegate())
        #expect(screen.router.finalDelegates.first?.isBodyweight == true)
        #expect(screen.router.finalDelegates.first?.equipmentVariations.isEmpty == true)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()
        screen.presenter.onViewDisappear()
        #expect(screen.interactor.trackedScreenEventNames == ["ExerciseEquipmentView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["ExerciseEquipmentView_Disappear"])
    }
}

// MARK: - Equipment Picker

/// The sheet that picks equipment for one row of the equipment step.
///
/// It owns nothing and writes straight into the binding the row handed it. Its one behaviour is
/// that a row is a toggle, so tapping a chosen item takes it back out rather than adding a second
/// copy of it to the variation.
@MainActor
struct EquipmentPickerPresenterTests {

    private final class Interactor: SpyGlobalInteractor, EquipmentPickerInteractor { }

    private final class Router: EquipmentPickerRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private func makeScreen() -> (EquipmentPickerPresenter, Interactor) {
        let interactor = Interactor()
        return (EquipmentPickerPresenter(interactor: interactor, router: Router()), interactor)
    }

    @Test("Test Pressing An Item Selects It And Pressing It Again Deselects It")
    func testPressingAnItemSelectsItAndPressingItAgainDeselectsIt() {
        let (presenter, interactor) = makeScreen()
        let box = EquipmentRefBox()
        presenter.onSelect(item: barbell, binding: box.binding)
        #expect(box.value == [barbell.ref])
        presenter.onSelect(item: barbell, binding: box.binding)
        #expect(box.value.isEmpty)
        #expect(interactor.playedHaptics.map { "\($0)" } == ["selection", "selection"])
    }

    /// A variation can combine equipment — a barbell in a rack — so choosing a second item adds to
    /// the first rather than replacing it, and deselecting one leaves the other behind.
    @Test("Test Several Items Can Be Held At Once")
    func testSeveralItemsCanBeHeldAtOnce() {
        let (presenter, _) = makeScreen()
        let box = EquipmentRefBox()
        presenter.onSelect(item: barbell, binding: box.binding)
        presenter.onSelect(item: dumbbell, binding: box.binding)
        presenter.onSelect(item: barbell, binding: box.binding)
        #expect(box.value == [dumbbell.ref])
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let (presenter, interactor) = makeScreen()
        presenter.onViewAppear()
        presenter.onViewDisappear()
        #expect(interactor.trackedScreenEventNames == ["EquipmentPickerView_Appear"])
        #expect(interactor.trackedEventNames == ["EquipmentPickerView_Disappear"])
    }
}

// MARK: - Final Exercise Details

/// Step four: the numbers and the free text — range of motion, stability, bodyweight contribution,
/// alternate names and a description.
///
/// The alternate names field is one comma-separated string that has to become a list, which is
/// where blank and padded entries creep in. Everything else is carried through untouched.
@MainActor
struct FinalExerciseDetailsPresenterTests {

    private final class Interactor: SpyGlobalInteractor, FinalExerciseDetailsInteractor {
        var currentUser: UserModel?
    }

    private final class Router: FinalExerciseDetailsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var saveDelegates: [ExerciseSaveDelegate] = []
        func showExerciseSaveView(delegate: ExerciseSaveDelegate) {
            saveDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: FinalExerciseDetailsPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(presenter: FinalExerciseDetailsPresenter(interactor: interactor, router: router), interactor: interactor, router: router)
    }

    private func delegate(isBodyweight: Bool = false) -> FinalExerciseDetailsDelegate {
        FinalExerciseDetailsDelegate(
            name: "Bench Press",
            trackableMetricA: .reps,
            trackableMetricB: .weight,
            exerciseType: .compoundUpper,
            laterality: .bilateral,
            targetMuscles: [.chest: .primary],
            isBodyweight: isBodyweight,
            equipmentVariations: isBodyweight ? [] : [EquipmentVariation(id: "v1", resistanceEquipment: [barbell.ref])]
        )
    }

    @Test("Test Everything Handed In Is Handed On")
    func testEverythingHandedInIsHandedOn() {
        let screen = makeScreen()
        screen.presenter.onNextPressed(delegate: delegate())
        let passed = screen.router.saveDelegates.first
        #expect(passed?.exerciseName == "Bench Press")
        #expect(passed?.trackableMetricA == .reps)
        #expect(passed?.trackableMetricB == .weight)
        #expect(passed?.type == .compoundUpper)
        #expect(passed?.laterality == .bilateral)
        #expect(passed?.targetMuscles == [.chest: .primary])
        #expect(passed?.isBodyweight == false)
        #expect(passed?.equipmentVariations.map(\.id) == ["v1"])
    }

    @Test("Test The Numbers Entered Here Reach The Save Step")
    func testTheNumbersEnteredHereReachTheSaveStep() {
        let screen = makeScreen()
        screen.presenter.rangeOfMotion = 4
        screen.presenter.stability = 2
        screen.presenter.bodyweightContribution = 60
        screen.presenter.exerciseDescription = "Press the bar off the chest."
        screen.presenter.onNextPressed(delegate: delegate(isBodyweight: true))
        let passed = screen.router.saveDelegates.first
        #expect(passed?.rangeOfMotion == 4)
        #expect(passed?.stability == 2)
        #expect(passed?.bodyweightContribution == 60)
        #expect(passed?.exerciseDescription == "Press the bar off the chest.")
    }

    /// The field is only shown for bodyweight exercises, so the default it holds must not be
    /// stored against everything else as if it meant something.
    @Test("Test A Loaded Exercise Stores No Bodyweight Contribution")
    func testALoadedExerciseStoresNoBodyweightContribution() {
        let screen = makeScreen()
        screen.presenter.onNextPressed(delegate: delegate())
        #expect(screen.router.saveDelegates.first?.bodyweightContribution == 0)
    }

    /// Labelled "Required" but never checked: any integer went through, including negatives.
    @Test("Test The Contribution Must Be A Percentage For A Bodyweight Exercise")
    func testTheContributionMustBeAPercentageForABodyweightExercise() {
        let screen = makeScreen()

        screen.presenter.bodyweightContribution = 140
        #expect(!screen.presenter.canContinue(delegate: delegate(isBodyweight: true)))
        #expect(screen.presenter.canContinue(delegate: delegate()))
        screen.presenter.onNextPressed(delegate: delegate(isBodyweight: true))
        #expect(screen.router.saveDelegates.isEmpty)

        screen.presenter.bodyweightContribution = 100
        #expect(screen.presenter.canContinue(delegate: delegate(isBodyweight: true)))
    }

    /// The footer used to be the literal placeholder "XX kg at your current weight."
    @Test("Test The Footer Shows The Weight Moved In The Users Unit")
    func testTheFooterShowsTheWeightMovedInTheUsersUnit() {
        let screen = makeScreen()
        screen.presenter.bodyweightContribution = 50

        #expect(screen.presenter.contributionFooter(delegate: delegate(isBodyweight: true)).hasPrefix("The share"))

        screen.interactor.currentUser = UserModel(userId: "user-1", submittedWeightKilograms: 80)
        #expect(screen.presenter.contributionFooter(delegate: delegate(isBodyweight: true)) == "About 40 kg at your current weight.")

        screen.interactor.currentUser = UserModel(userId: "user-1", submittedWeightKilograms: 80, submittedWeightUnitPreference: .pounds)
        #expect(screen.presenter.contributionFooter(delegate: delegate(isBodyweight: true)) == "About 88 lbs at your current weight.")
    }

    /// The field's footer tells the user to separate names with a comma, and people type a space
    /// after the comma. A name stored with a leading space shows up padded wherever it is listed.
    @Test("Test Alternate Names Are Split And Trimmed")
    func testAlternateNamesAreSplitAndTrimmed() {
        let screen = makeScreen()
        screen.presenter.alternateNames = "Barbell Bench, Flat Bench ,Chest Press"
        screen.presenter.onNextPressed(delegate: delegate())
        #expect(screen.router.saveDelegates.first?.alternativeNames == ["Barbell Bench", "Flat Bench", "Chest Press"])
    }

    /// The field is optional. Splitting an untouched one on commas yields a single empty name,
    /// which would be stored against the exercise and shown on its detail screen.
    @Test("Test An Untouched Field Carries No Alternate Names")
    func testAnUntouchedFieldCarriesNoAlternateNames() {
        let screen = makeScreen()
        screen.presenter.onNextPressed(delegate: delegate())
        #expect(screen.router.saveDelegates.first?.alternativeNames.isEmpty == true)
    }

    /// The same problem mid-typing: a trailing comma must not leave a blank name behind it, which
    /// the detail screen renders as a dangling ", ".
    @Test("Test A Trailing Comma Leaves No Blank Name")
    func testATrailingCommaLeavesNoBlankName() {
        let screen = makeScreen()
        screen.presenter.alternateNames = "Barbell Bench, "
        screen.presenter.onNextPressed(delegate: delegate())
        #expect(screen.router.saveDelegates.first?.alternativeNames == ["Barbell Bench"])
    }

    /// Most exercises are not bodyweight, so the percentage starts somewhere sensible rather than
    /// at zero, which would read as an exercise that moves nothing.
    @Test("Test The Bodyweight Contribution Starts At Seventy Five")
    func testTheBodyweightContributionStartsAtSeventyFive() {
        #expect(makeScreen().presenter.bodyweightContribution == 75)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()
        screen.presenter.onViewAppear(delegate: delegate())
        screen.presenter.onViewDisappear(delegate: delegate())
        #expect(screen.interactor.trackedScreenEventNames == ["FinalExerciseDetailsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["FinalExerciseDetailsView_Disappear"])
    }
}

// MARK: - Exercise Save

/// The last step: a summary of everything collected, and the button that writes the exercise.
///
/// This is where four screens' worth of hand-assembled delegates finally become one stored model,
/// so the test worth having is that every field arrives in it. The failure alert goes out through
/// `showSimpleAlert`, a `GlobalRouter` extension method this screen's router does not restate — it
/// is statically dispatched and a double can never see it, so the failure test asserts that
/// nothing was stored instead.
@MainActor
struct ExerciseSavePresenterTests {

    private final class Interactor: SpyGlobalInteractor, ExerciseSaveInteractor {
        var currentUser: UserModel?
        var saveError: Error?
        var saveDelay: Duration = .zero
        private(set) var saved: [ExerciseModel] = []

        func saveExerciseModel(exercise: ExerciseModel, image: PlatformImage?) async throws {
            try? await Task.sleep(for: saveDelay)
            if let saveError {
                throw saveError
            }
            saved.append(exercise)
        }
    }

    private final class Router: ExerciseSaveRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private struct Screen {
        let presenter: ExerciseSavePresenter
        let interactor: Interactor
        let router: Router
    }

    private struct SaveFailure: Error { }

    private func makeScreen(user: UserModel? = UserModel(userId: "user-1")) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = user
        let router = Router()
        return Screen(presenter: ExerciseSavePresenter(interactor: interactor, router: router), interactor: interactor, router: router)
    }

    private func delegate(metricB: TrackableExerciseMetric? = .weight) -> ExerciseSaveDelegate {
        ExerciseSaveDelegate(
            exerciseName: "Bench Press",
            trackableMetricA: .reps,
            trackableMetricB: metricB,
            type: .compoundUpper,
            laterality: .bilateral,
            targetMuscles: [.chest: .primary, .triceps: .secondary],
            isBodyweight: false,
            equipmentVariations: [EquipmentVariation(id: "v1", resistanceEquipment: [barbell.ref])],
            rangeOfMotion: 4,
            stability: 2,
            bodyweightContribution: 60,
            alternativeNames: ["Flat Bench"],
            exerciseDescription: "Press the bar off the chest."
        )
    }

    @Test("Test The Stored Exercise Carries Everything The Flow Collected")
    func testTheStoredExerciseCarriesEverythingTheFlowCollected() async {
        let screen = makeScreen()
        screen.presenter.onCreatePressed(delegate: delegate())
        _ = await TestManagers.eventually { screen.interactor.saved.count == 1 }
        let stored = screen.interactor.saved.first
        #expect(stored?.name == "Bench Press")
        #expect(stored?.description == "Press the bar off the chest.")
        #expect(stored?.type == .compoundUpper)
        #expect(stored?.laterality == .bilateral)
        #expect(stored?.muscleGroups == [.chest: .primary, .triceps: .secondary])
        #expect(stored?.isBodyweight == false)
        #expect(stored?.equipmentVariations.map(\.id) == ["v1"])
        #expect(stored?.rangeOfMotion == 4)
        #expect(stored?.stability == 2)
        #expect(stored?.bodyWeightContribution == 60)
        #expect(stored?.alternateNames == ["Flat Bench"])
    }

    /// The two metric boxes become one ordered list, and the first is the one the exercise is
    /// primarily logged against, so the order matters. A second metric that was never chosen must
    /// not leave a hole in it.
    @Test("Test The Metrics Are Stored In The Order They Were Chosen")
    func testTheMetricsAreStoredInTheOrderTheyWereChosen() async {
        let both = makeScreen()
        both.presenter.onCreatePressed(delegate: delegate())
        _ = await TestManagers.eventually { both.interactor.saved.count == 1 }
        #expect(both.interactor.saved.first?.trackableMetrics == [.reps, .weight])

        let one = makeScreen()
        one.presenter.onCreatePressed(delegate: delegate(metricB: nil))
        _ = await TestManagers.eventually { one.interactor.saved.count == 1 }
        #expect(one.interactor.saved.first?.trackableMetrics == [.reps])
    }

    /// A custom exercise belongs to whoever made it, and must never be filed alongside the prebuilt
    /// library — a system exercise is not theirs to edit or delete.
    /// Create had no in-flight state, so a second tap while the first save was in progress
    /// stored the exercise twice.
    @Test("Test A Second Tap During A Save Stores Nothing Extra")
    func testASecondTapDuringASaveStoresNothingExtra() async {
        let screen = makeScreen()
        screen.interactor.saveDelay = .milliseconds(150)

        screen.presenter.onCreatePressed(delegate: delegate())
        #expect(screen.presenter.isSaving)
        screen.presenter.onCreatePressed(delegate: delegate())

        _ = await TestManagers.eventually { !screen.interactor.saved.isEmpty }
        try? await Task.sleep(for: .milliseconds(100))
        #expect(screen.interactor.saved.count == 1)
        #expect(!screen.presenter.isSaving)
    }

    @Test("Test The Exercise Belongs To The Signed In User")
    func testTheExerciseBelongsToTheSignedInUser() async {
        let screen = makeScreen(user: UserModel(userId: "user-42"))
        screen.presenter.onCreatePressed(delegate: delegate())
        _ = await TestManagers.eventually { screen.interactor.saved.count == 1 }
        #expect(screen.interactor.saved.first?.authorId == "user-42")
        #expect(screen.interactor.saved.first?.isSystemExercise == false)
        #expect(await TestManagers.eventually { !screen.interactor.playedHaptics.isEmpty })
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
    }

    /// With nobody signed in there is no author to file the exercise under, so it is not written at
    /// all rather than stored against an empty id.
    @Test("Test Nothing Is Stored When Nobody Is Signed In")
    func testNothingIsStoredWhenNobodyIsSignedIn() async {
        let screen = makeScreen(user: nil)
        screen.presenter.onCreatePressed(delegate: delegate())
        _ = await TestManagers.eventually { !screen.interactor.saved.isEmpty }
        #expect(screen.interactor.saved.isEmpty)
    }

    @Test("Test A Failed Save Stores Nothing")
    func testAFailedSaveStoresNothing() async {
        let screen = makeScreen()
        screen.interactor.saveError = SaveFailure()
        screen.presenter.onCreatePressed(delegate: delegate())
        _ = await TestManagers.eventually { !screen.interactor.saved.isEmpty }
        #expect(screen.interactor.saved.isEmpty)
        #expect(await TestManagers.eventually { !screen.interactor.playedHaptics.isEmpty })
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["error"])
    }

    // MARK: - The create funnel

    /// This is where the whole wizard lands, so it is the only place that can say whether an
    /// exercise was actually created. It used to report neither the attempt nor the outcome.
    @Test("Test Creating An Exercise Reports Start Then Success")
    func testCreatingAnExerciseReportsStartThenSuccess() async {
        let screen = makeScreen()

        screen.presenter.onCreatePressed(delegate: delegate())
        _ = await TestManagers.eventually { screen.interactor.trackedEventNames.count == 2 }

        #expect(screen.interactor.trackedEventNames == ["CreateExercise_Start", "CreateExercise_Success"])
    }

    /// The alert told the user; nothing told us, so a backend outage here was indistinguishable
    /// from nobody reaching the last step of the wizard.
    @Test("Test A Failed Save Reports The Failure")
    func testAFailedSaveReportsTheFailure() async {
        let screen = makeScreen()
        screen.interactor.saveError = SaveFailure()

        screen.presenter.onCreatePressed(delegate: delegate())
        _ = await TestManagers.eventually { screen.interactor.trackedEventNames.count == 2 }

        #expect(screen.interactor.trackedEventNames == ["CreateExercise_Start", "CreateExercise_Fail"])
    }

    /// The signed-out branch returned before anything was tracked, so it lost the attempt as well
    /// as the exercise.
    @Test("Test No Signed In User Reports The Failure")
    func testNoSignedInUserReportsTheFailure() {
        let screen = makeScreen(user: nil)

        screen.presenter.onCreatePressed(delegate: delegate())

        #expect(screen.interactor.trackedEventNames == ["CreateExercise_Start", "CreateExercise_Fail"])
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()
        screen.presenter.onViewAppear(delegate: delegate())
        screen.presenter.onViewDisappear(delegate: delegate())
        #expect(screen.interactor.trackedScreenEventNames == ["ExerciseSaveView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["ExerciseSaveView_Disappear"])
    }
}
