//
//  MesocycleSettingsFlowPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// A failure for the interactor doubles to throw, so the tests can drive the unhappy path.
private struct MesocycleFlowTestError: Error { }

/// A flag a `@Sendable` completion closure can set.
///
/// Every step of this wizard copies the previous step's `onComplete` onto the delegate it builds,
/// and that closure is what returns the user to onboarding once the mesocycle is saved. Dropping it
/// cannot be seen by comparing delegates — the only way to know it survived is to call it.
private final class CompletionFlag: @unchecked Sendable {
    private(set) var fired = false

    func fire() {
        fired = true
    }
}

/// The mesocycle settings sheet: name, colour and icon, day order, deload and activation.
///
/// Every setting here is edited through a `Binding` onto the mesocycle being designed, so each row
/// is a pair — what it hands the editor to start from, and what it writes back when the editor
/// saves. A row that hands over the wrong value shows the user the wrong starting point; a row
/// that writes back to the wrong field loses their change.
@MainActor
struct MesocycleSettingsFlowTests {

    private final class Interactor: SpyGlobalInteractor, MesocycleSettingsInteractor {
        var saveMesocycleError: Error?
        private(set) var savedMesocycles: [Mesocycle] = []
        private(set) var activatedMesocycleIds: [String] = []

        func saveMesocycle(mesocycle: Mesocycle) async throws {
            if let saveMesocycleError { throw saveMesocycleError }
            savedMesocycles.append(mesocycle)
        }

        func setActiveMesocycle(mesocycleId: String) async throws {
            activatedMesocycleIds.append(mesocycleId)
        }
    }

    private final class Router: MesocycleSettingsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var renameDelegates: [RenameWorkoutTemplateModelDelegate] = []
        private(set) var colourIconStarts: [(colour: String, icon: String)] = []
        private(set) var colourIconSaves: [(String, String) -> Void] = []
        private(set) var dayOrderStarts: [[WorkoutTemplateModel]] = []
        private(set) var dayOrderSaves: [([WorkoutTemplateModel]) -> Void] = []
        private(set) var deloadStarts: [DeloadType] = []
        private(set) var deloadSaves: [(DeloadType) -> Void] = []

        func showRenameMesocycleView(delegate: RenameWorkoutTemplateModelDelegate) {
            renameDelegates.append(delegate)
        }

        func showEditMesocycleColourIconView(colour: String, icon: String, onSave: @escaping (String, String) -> Void) {
            colourIconStarts.append((colour, icon))
            colourIconSaves.append(onSave)
        }

        func showEditDayOrderView(dayPlans: [WorkoutTemplateModel], onSave: @escaping ([WorkoutTemplateModel]) -> Void) {
            dayOrderStarts.append(dayPlans)
            dayOrderSaves.append(onSave)
        }

        func showEditDeloadView(selected: DeloadType, onSave: @escaping (DeloadType) -> Void) {
            deloadStarts.append(selected)
            deloadSaves.append(onSave)
        }
    }

    /// Holds the mesocycle the sheet edits, and exposes the `Binding` the design screen passes in.
    /// `Binding`'s accessors are `@Sendable`, so the value has to live somewhere that can be
    /// reached from one — hence a box rather than a local, main-actor isolated so it is
    /// `Sendable`.
    @MainActor
    private final class MutableMesocycle {
        var value: Mesocycle

        init(_ value: Mesocycle) {
            self.value = value
        }

        var binding: Binding<Mesocycle> {
            Binding(
                get: { MainActor.assumeIsolated { self.value } },
                set: { newValue in MainActor.assumeIsolated { self.value = newValue } }
            )
        }
    }

    private struct Screen {
        let presenter: MesocycleSettingsPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: MesocycleSettingsPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func day(_ name: String) -> WorkoutTemplateModel {
        WorkoutTemplateModel(id: name, authorId: "user-1", name: name)
    }

    private func box() -> MutableMesocycle {
        MutableMesocycle(
            Mesocycle(
                id: "program-1",
                authorId: "user-1",
                name: "Block",
                icon: "flag",
                colour: "#FF0000",
                deload: .none,
                workoutTemplates: [day("Push"), day("Pull"), day("Legs")]
            )
        )
    }

    // MARK: - Name

    @Test("Test Renaming Starts From The Programs Current Name")
    func testRenamingStartsFromTheMesocyclesCurrentName() {
        let screen = makeScreen()
        let mesocycle = box()

        screen.presenter.onEditNamePressed(mesocycle: mesocycle.binding)

        #expect(screen.router.renameDelegates.first?.initialName == "Block")
    }

    @Test("Test A New Name Is Written Back To The Program")
    func testANewNameIsWrittenBackToTheMesocycle() {
        let screen = makeScreen()
        let mesocycle = box()

        screen.presenter.onEditNamePressed(mesocycle: mesocycle.binding)
        screen.router.renameDelegates.first?.onSave("Strength Block")

        #expect(mesocycle.value.name == "Strength Block")
    }

    // MARK: - Colour and icon

    @Test("Test The Colour Editor Starts From The Programs Colour And Icon")
    func testTheColourEditorStartsFromTheMesocyclesColourAndIcon() {
        let screen = makeScreen()
        let mesocycle = box()

        screen.presenter.onEditColourIconPressed(mesocycle: mesocycle.binding)

        #expect(screen.router.colourIconStarts.first?.colour == "#FF0000")
        #expect(screen.router.colourIconStarts.first?.icon == "flag")
    }

    /// Colour and icon are chosen on one screen and written back together — writing one and
    /// dropping the other leaves the mesocycle half-changed.
    @Test("Test A New Colour And Icon Are Both Written Back")
    func testANewColourAndIconAreBothWrittenBack() {
        let screen = makeScreen()
        let mesocycle = box()

        screen.presenter.onEditColourIconPressed(mesocycle: mesocycle.binding)
        screen.router.colourIconSaves.first?("#00FF00", "sailboat.fill")

        #expect(mesocycle.value.colour == "#00FF00")
        #expect(mesocycle.value.icon == "sailboat.fill")
    }

    // MARK: - Day order

    @Test("Test The Day Order Editor Starts From The Programs Days")
    func testTheDayOrderEditorStartsFromTheMesocyclesDays() {
        let screen = makeScreen()
        let mesocycle = box()

        screen.presenter.onEditDayOrderPressed(mesocycle: mesocycle.binding)

        #expect(screen.router.dayOrderStarts.first?.map(\.name) == ["Push", "Pull", "Legs"])
    }

    /// The order of the days is the order they are trained in, so this write is the whole point of
    /// the screen.
    @Test("Test A New Day Order Is Written Back To The Program")
    func testANewDayOrderIsWrittenBackToTheMesocycle() {
        let screen = makeScreen()
        let mesocycle = box()

        screen.presenter.onEditDayOrderPressed(mesocycle: mesocycle.binding)
        screen.router.dayOrderSaves.first?([day("Legs"), day("Push"), day("Pull")])

        #expect(mesocycle.value.workoutTemplates.map(\.name) == ["Legs", "Push", "Pull"])
    }

    // MARK: - Deload

    @Test("Test The Deload Editor Starts From The Programs Deload")
    func testTheDeloadEditorStartsFromTheMesocyclesDeload() {
        let screen = makeScreen()
        let mesocycle = box()
        mesocycle.value.deload = .start

        screen.presenter.onEditDeloadPressed(mesocycle: mesocycle.binding)

        #expect(screen.router.deloadStarts.first == .start)
    }

    @Test("Test A New Deload Is Written Back To The Program")
    func testANewDeloadIsWrittenBackToTheMesocycle() {
        let screen = makeScreen()
        let mesocycle = box()

        screen.presenter.onEditDeloadPressed(mesocycle: mesocycle.binding)
        screen.router.deloadSaves.first?(.end)

        #expect(mesocycle.value.deload == .end)
    }

    // MARK: - Activation

    /// Activating stores the mesocycle before pointing the user at it. The other order would leave
    /// the user following a mesocycle the backend has never been told about.
    @Test("Test Activating Saves The Program Before Making It Active")
    func testActivatingSavesTheMesocycleBeforeMakingItActive() async {
        let screen = makeScreen()
        let mesocycle = box()

        screen.presenter.onActivatePressed(mesocycle: mesocycle.value)

        #expect(await TestManagers.eventually { !screen.interactor.activatedMesocycleIds.isEmpty })
        #expect(screen.interactor.savedMesocycles.map(\.id) == ["program-1"])
        #expect(screen.interactor.activatedMesocycleIds == ["program-1"])
        #expect(await TestManagers.eventually { !screen.interactor.playedHaptics.isEmpty })
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
    }

    /// If the mesocycle could not be stored, activating it would point the user at nothing.
    @Test("Test A Failed Save Does Not Activate The Program")
    func testAFailedSaveDoesNotActivateTheMesocycle() async {
        let screen = makeScreen()
        let mesocycle = box()
        screen.interactor.saveMesocycleError = MesocycleFlowTestError()

        screen.presenter.onActivatePressed(mesocycle: mesocycle.value)

        _ = await TestManagers.eventually(timeout: .milliseconds(200)) { !screen.interactor.activatedMesocycleIds.isEmpty }
        #expect(screen.interactor.activatedMesocycleIds.isEmpty)
        #expect(await TestManagers.eventually { !screen.interactor.playedHaptics.isEmpty })
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["error"])
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["ProgramSettingsView_Appear"])
    }
}

/// The colour and icon editor reached from mesocycle settings.
///
/// It takes the mesocycle's colour as a hex string and hands one back, so the risk is the round
/// trip: a colour that does not survive being parsed and re-encoded changes every time the sheet
/// is opened and saved.
@MainActor
struct MesocycleFlowColourIconEditorTests {

    private final class Router: EditMesocycleColourIconRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    /// Records what the sheet handed back, since the dismissal it also performs goes through a
    /// `GlobalRouter` extension method that a double cannot intercept.
    private final class SaveRecorder {
        private(set) var saves: [(colour: String, icon: String)] = []

        func record(_ colour: String, _ icon: String) {
            saves.append((colour, icon))
        }
    }

    private func makeScreen(
        colour: String = "#FF0000",
        icon: String = "flag"
    ) -> (EditMesocycleColourIconPresenter, SaveRecorder) {
        let recorder = SaveRecorder()
        let presenter = EditMesocycleColourIconPresenter(
            colour: colour,
            icon: icon,
            onSave: { recorder.record($0, $1) },
            router: Router()
        )
        return (presenter, recorder)
    }

    @Test("Test The Editor Opens On The Programs Colour And Icon")
    func testTheEditorOpensOnTheMesocyclesColourAndIcon() {
        let (presenter, _) = makeScreen(colour: "#00FF00", icon: "sailboat.fill")

        #expect(presenter.selectedColour.asHex() == "#00FF00")
        #expect(presenter.selectedIcon == "sailboat.fill")
    }

    /// Opening the sheet and saving without touching anything must give back exactly what it was
    /// given, or the mesocycle's colour drifts a little every time settings are opened.
    @Test("Test Saving Without Changing Anything Gives The Same Colour Back")
    func testSavingWithoutChangingAnythingGivesTheSameColourBack() {
        let (presenter, recorder) = makeScreen(colour: "#00FF00", icon: "sailboat.fill")

        presenter.onSavePressed()

        #expect(recorder.saves.first?.colour == "#00FF00")
        #expect(recorder.saves.first?.icon == "sailboat.fill")
    }

    @Test("Test A Chosen Colour And Icon Are Handed Back")
    func testAChosenColourAndIconAreHandedBack() {
        let (presenter, recorder) = makeScreen()

        presenter.onColourPressed(Color(hex: "#123456"))
        presenter.onIconPressed("gamecontroller")
        presenter.onSavePressed()

        #expect(recorder.saves.first?.colour == "#123456")
        #expect(recorder.saves.first?.icon == "gamecontroller")
    }

    @Test("Test Cancelling Changes Nothing")
    func testCancellingChangesNothing() {
        let (presenter, recorder) = makeScreen()

        presenter.onColourPressed(.green)
        presenter.onCancelPressed()

        #expect(recorder.saves.isEmpty)
    }

    @Test("Test The Editor Offers The Programs Palette")
    func testTheEditorOffersTheMesocyclesPalette() {
        let (presenter, _) = makeScreen()

        #expect(presenter.colours == MesocycleIconPresenter.defaultColours)
        #expect(presenter.icons == MesocycleIconPresenter.defaultIcons)
    }
}

/// The deload editor reached from mesocycle settings.
///
/// Deload decides whether a block starts or ends with a lighter cycle, so picking one and having
/// the other stored would change how the whole block is trained.
@MainActor
struct MesocycleFlowEditDeloadPresenterTests {

    private final class Router: EditDeloadRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    /// The dismissal that accompanies a save goes through a `GlobalRouter` extension method, which
    /// a double cannot intercept — so only the handed-back value is recorded.
    private final class SaveRecorder {
        private(set) var saves: [DeloadType] = []

        func record(_ type: DeloadType) {
            saves.append(type)
        }
    }

    private func makeScreen(selected: DeloadType = .none) -> (EditDeloadPresenter, SaveRecorder) {
        let recorder = SaveRecorder()
        let presenter = EditDeloadPresenter(
            selected: selected,
            onSave: { recorder.record($0) },
            router: Router()
        )
        return (presenter, recorder)
    }

    @Test("Test Every Deload Option Is Offered")
    func testEveryDeloadOptionIsOffered() {
        let (presenter, _) = makeScreen()

        #expect(presenter.allCases == [.none, .start, .end])
    }

    @Test("Test The Editor Opens On The Programs Deload")
    func testTheEditorOpensOnTheMesocyclesDeload() {
        let (presenter, _) = makeScreen(selected: .end)

        #expect(presenter.selected == .end)
    }

    @Test("Test The Chosen Deload Is Handed Back")
    func testTheChosenDeloadIsHandedBack() {
        let (presenter, recorder) = makeScreen()

        presenter.onSelect(.start)
        presenter.onSavePressed()

        #expect(recorder.saves == [.start])
    }

    @Test("Test Cancelling Keeps The Programs Deload")
    func testCancellingKeepsTheMesocyclesDeload() {
        let (presenter, recorder) = makeScreen(selected: .none)

        presenter.onSelect(.end)
        presenter.onCancelPressed()

        #expect(recorder.saves.isEmpty)
    }
}

/// The day-order editor reached from mesocycle settings.
///
/// The order of the days is the order they are trained in, and the list hands its moves over in
/// SwiftUI's offset terms — where the destination is measured before the moved row is taken out.
/// Getting that wrong shifts every day by one.
@MainActor
struct MesocycleFlowEditDayOrderPresenterTests {

    private final class Router: EditDayOrderRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    /// The dismissal that accompanies a save goes through a `GlobalRouter` extension method, which
    /// a double cannot intercept — so only the handed-back order is recorded.
    private final class SaveRecorder {
        private(set) var saves: [[WorkoutTemplateModel]] = []

        func record(_ plans: [WorkoutTemplateModel]) {
            saves.append(plans)
        }
    }

    private func day(_ name: String) -> WorkoutTemplateModel {
        WorkoutTemplateModel(id: name, authorId: "user-1", name: name)
    }

    private func makeScreen(_ names: [String] = ["Push", "Pull", "Legs"]) -> (EditDayOrderPresenter, SaveRecorder) {
        let recorder = SaveRecorder()
        let presenter = EditDayOrderPresenter(
            dayPlans: names.map { day($0) },
            onSave: { recorder.record($0) },
            router: Router()
        )
        return (presenter, recorder)
    }

    @Test("Test The Editor Opens On The Programs Day Order")
    func testTheEditorOpensOnTheMesocyclesDayOrder() {
        let (presenter, _) = makeScreen()

        #expect(presenter.dayPlans.map(\.name) == ["Push", "Pull", "Legs"])
    }

    /// Dragging the last day to the top: the destination is the index it lands on.
    @Test("Test Moving A Day Upwards Puts It At The Destination")
    func testMovingADayUpwardsPutsItAtTheDestination() {
        let (presenter, _) = makeScreen()

        presenter.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(presenter.dayPlans.map(\.name) == ["Legs", "Push", "Pull"])
    }

    /// Dragging downwards, the destination is measured before the row is lifted out — so moving the
    /// first day "to 2" leaves it second, not third. This is the arithmetic an off-by-one would
    /// break.
    @Test("Test Moving A Day Downwards Counts The Destination Before The Move")
    func testMovingADayDownwardsCountsTheDestinationBeforeTheMove() {
        let (presenter, _) = makeScreen()

        presenter.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        #expect(presenter.dayPlans.map(\.name) == ["Pull", "Push", "Legs"])
    }

    @Test("Test Moving A Day To The End Puts It Last")
    func testMovingADayToTheEndPutsItLast() {
        let (presenter, _) = makeScreen()

        presenter.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        #expect(presenter.dayPlans.map(\.name) == ["Pull", "Legs", "Push"])
    }

    @Test("Test Saving Hands Back The New Order")
    func testSavingHandsBackTheNewOrder() {
        let (presenter, recorder) = makeScreen()

        presenter.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        presenter.onSavePressed()

        #expect(recorder.saves.first?.map(\.name) == ["Legs", "Push", "Pull"])
    }

    /// Reordering is destructive to a training week, so backing out must leave the mesocycle alone.
    @Test("Test Cancelling Keeps The Programs Day Order")
    func testCancellingKeepsTheMesocyclesDayOrder() {
        let (presenter, recorder) = makeScreen()

        presenter.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        presenter.onCancelPressed()

        #expect(recorder.saves.isEmpty)
    }
}

/// The sheet for renaming a day of the mesocycle.
///
/// A day's name is what the dashboard matches logged sessions against, so a name that is blank or
/// padded with spaces is worse than no rename at all.
@MainActor
struct MesocycleFlowRenameDayPlanPresenterTests {

    private final class Interactor: RenameWorkoutTemplateModelInteractor { }

    private final class Router: RenameWorkoutTemplateModelRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    /// The dismissal that accompanies a save goes through a `GlobalRouter` extension method, which
    /// a double cannot intercept — so only the handed-back name is recorded.
    private final class SaveRecorder {
        private(set) var saves: [String] = []

        func record(_ name: String) {
            saves.append(name)
        }
    }

    private func makeScreen(initialName: String = "Push") -> RenameWorkoutTemplateModelPresenter {
        RenameWorkoutTemplateModelPresenter(
            interactor: Interactor(),
            router: Router(),
            initialName: initialName
        )
    }

    @Test("Test The Sheet Opens On The Days Current Name")
    func testTheSheetOpensOnTheDaysCurrentName() {
        let presenter = makeScreen()

        #expect(presenter.nameText == "Push")
        #expect(presenter.canSave)
    }

    @Test("Test A Blank Name Cannot Be Saved")
    func testABlankNameCannotBeSaved() {
        let presenter = makeScreen()
        presenter.nameText = "   "

        #expect(!presenter.canSave)
    }

    /// Pressing save with only spaces typed must not rename the day to nothing, even if the button
    /// were somehow reachable.
    @Test("Test Saving A Blank Name Renames Nothing")
    func testSavingABlankNameRenamesNothing() {
        let presenter = makeScreen()
        let recorder = SaveRecorder()
        presenter.nameText = "  "

        presenter.onSavePressed(onSave: { recorder.record($0) })

        #expect(recorder.saves.isEmpty)
    }

    /// Stray spaces around a typed name would make the day fail to match the sessions logged
    /// against it, so the name is trimmed on the way out.
    @Test("Test A Typed Name Is Trimmed On The Way Out")
    func testATypedNameIsTrimmedOnTheWayOut() {
        let presenter = makeScreen()
        let recorder = SaveRecorder()
        presenter.nameText = "  Leg Day  "

        presenter.onSavePressed(onSave: { recorder.record($0) })

        #expect(recorder.saves == ["Leg Day"])
    }
}
