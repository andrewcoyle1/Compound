//
//  GymProfilePresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The gym profile: which equipment a gym has, across eleven kinds of it.
///
/// The screen shows each kind as a searchable, filterable list, and every row is editable in place.
/// That is the awkward part: the rows are sorted by name but the bindings have to write back to the
/// item's position in the *unsorted* array. Handing a row the binding for its display position
/// instead would let a user edit one dumbbell and change another, which is why the write-back is
/// pinned here rather than left to the view.
///
/// Leaving the screen saves what was changed; an unnamed profile is kept as "Untitled Gym Profile".
@MainActor
struct GymProfilePresenterTests {

    private final class Interactor: SpyGlobalInteractor, GymProfileInteractor {
        var currentUser: UserModel?
        private(set) var savedProfiles: [GymProfileModel] = []
        private(set) var favouritedIds: [String?] = []
        var saveError: Error?

        func saveGymProfile(profile: GymProfileModel, image: PlatformImage?) async throws {
            if let saveError { throw saveError }
            savedProfiles.append(profile)
        }

        func updateFavouriteGymProfileId(profileId: String?) async throws {
            favouritedIds.append(profileId)
        }
    }

    private final class Router: SpyOnboardingRouter, GymProfileRouter {
        func showEditFreeWeightView(freeWeight: Binding<FreeWeights>) { record("editFreeWeight") }
        func showEditLoadableBarView(loadableBar: Binding<LoadableBars>) { record("editLoadableBar") }
        func showEditFixedWeightBarView(fixedWeightBar: Binding<FixedWeightBars>) { record("editFixedWeightBar") }
        func showEditBandView(band: Binding<Bands>) { record("editBand") }
        func showEditBodyWeightView(bodyWeight: Binding<BodyWeights>) { record("editBodyWeight") }
        func showEditLoadableAccessoryView(loadableAccessory: Binding<LoadableAccessoryEquipment>) { record("editLoadableAccessory") }
        func showEditStackMachineView<Machine: StackMachine>(machine: Binding<Machine>) { record("editStackMachine") }
        func showEditPlateLoadedMachineView(plateLoadedMachine: Binding<PlateLoadedMachine>) { record("editPlateLoadedMachine") }
        private(set) var addMachineDelegates: [AddGymMachineDelegate] = []
        func showAddGymMachineView(delegate: AddGymMachineDelegate) {
            addMachineDelegates.append(delegate)
            record("addMachine")
        }
    }

    private struct Screen {
        let presenter: GymProfilePresenter
        let interactor: Interactor
        let router: Router
    }

    /// Saving happens in a detached `Task`, so a test has to let the loop turn before asserting.
    private func settle() async {
        for _ in 0..<10 {
            await Task.yield()
        }
    }

    private func freeWeight(_ name: String, id: String? = nil, isActive: Bool = false) -> FreeWeights {
        FreeWeights(
            id: id ?? name.lowercased(),
            name: name,
            needsColour: false,
            range: [],
            isActive: isActive
        )
    }

    private func makeScreen(
        name: String = "Home Gym",
        freeWeights: [FreeWeights] = [],
        user: UserModel? = nil
    ) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = user
        let router = Router()
        let profile = GymProfileModel(
            id: "gym-1",
            authorId: "author-1",
            name: name,
            freeWeights: freeWeights
        )
        return Screen(
            presenter: GymProfilePresenter(interactor: interactor, router: router, gymProfile: profile),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - Listing equipment

    @Test("Test Every Piece Of Equipment Is Listed By Default")
    func testEveryPieceOfEquipmentIsListedByDefault() {
        let screen = makeScreen(freeWeights: [freeWeight("Dumbbells"), freeWeight("Kettlebells")])

        #expect(screen.presenter.filteredFreeWeights.count == 2)
    }

    @Test("Test Equipment Is Listed In Name Order")
    func testEquipmentIsListedInNameOrder() {
        let screen = makeScreen(freeWeights: [
            freeWeight("Kettlebells"),
            freeWeight("Dumbbells"),
            freeWeight("Medicine Balls")
        ])

        let names = screen.presenter.filteredFreeWeights.map(\.wrappedValue.name)

        #expect(names == ["Dumbbells", "Kettlebells", "Medicine Balls"])
    }

    /// Sorting is by what the name reads as, not by where its capitals fall.
    @Test("Test Case Does Not Affect The Order")
    func testCaseDoesNotAffectTheOrder() {
        let screen = makeScreen(freeWeights: [
            freeWeight("kettlebells", id: "k"),
            freeWeight("Dumbbells", id: "d")
        ])

        #expect(screen.presenter.filteredFreeWeights.map(\.wrappedValue.id) == ["d", "k"])
    }

    /// Two pieces of equipment with the same name keep the order the profile holds them in, so the
    /// list does not reshuffle between reads.
    @Test("Test Equal Names Keep Their Original Order")
    func testEqualNamesKeepTheirOriginalOrder() {
        let screen = makeScreen(freeWeights: [
            freeWeight("Dumbbells", id: "first"),
            freeWeight("Dumbbells", id: "second")
        ])

        #expect(screen.presenter.filteredFreeWeights.map(\.wrappedValue.id) == ["first", "second"])
    }

    // MARK: - Search

    @Test("Test Searching Narrows The List")
    func testSearchingNarrowsTheList() {
        let screen = makeScreen(freeWeights: [freeWeight("Dumbbells"), freeWeight("Kettlebells")])

        screen.presenter.searchQuery = "dumb"

        #expect(screen.presenter.filteredFreeWeights.map(\.wrappedValue.name) == ["Dumbbells"])
    }

    @Test("Test Search Ignores Case")
    func testSearchIgnoresCase() {
        let screen = makeScreen(freeWeights: [freeWeight("Dumbbells")])

        screen.presenter.searchQuery = "DUMBBELLS"

        #expect(screen.presenter.filteredFreeWeights.count == 1)
    }

    /// A query of only spaces is someone who has not typed anything yet, not a search for a space.
    @Test("Test A Whitespace Query Is No Query At All")
    func testAWhitespaceQueryIsNoQueryAtAll() {
        let screen = makeScreen(freeWeights: [freeWeight("Dumbbells"), freeWeight("Kettlebells")])

        screen.presenter.searchQuery = "   "

        #expect(screen.presenter.filteredFreeWeights.count == 2)
    }

    @Test("Test A Query Matching Nothing Empties The List")
    func testAQueryMatchingNothingEmptiesTheList() {
        let screen = makeScreen(freeWeights: [freeWeight("Dumbbells")])

        screen.presenter.searchQuery = "treadmill"

        #expect(screen.presenter.filteredFreeWeights.isEmpty)
    }

    /// The screen shows a "no results" state only when a real query hid every section.
    @Test("Test No Matching Equipment Needs A Query That Hides Everything")
    func testNoMatchingEquipmentNeedsAQueryThatHidesEverything() {
        let screen = makeScreen(freeWeights: [freeWeight("Dumbbells")])
        #expect(!screen.presenter.hasNoMatchingEquipment)

        screen.presenter.searchQuery = "dumb"
        #expect(!screen.presenter.hasNoMatchingEquipment)

        screen.presenter.searchQuery = "treadmill"
        #expect(screen.presenter.hasNoMatchingEquipment)
    }

    // MARK: - The selected filter

    @Test("Test The Selected Filter Shows Only Equipment The Gym Has")
    func testTheSelectedFilterShowsOnlyEquipmentTheGymHas() {
        let screen = makeScreen(freeWeights: [
            freeWeight("Dumbbells", isActive: true),
            freeWeight("Kettlebells", isActive: false)
        ])

        screen.presenter.filter = .selected

        #expect(screen.presenter.filteredFreeWeights.map(\.wrappedValue.name) == ["Dumbbells"])
    }

    @Test("Test Search And The Selected Filter Apply Together")
    func testSearchAndTheSelectedFilterApplyTogether() {
        let screen = makeScreen(freeWeights: [
            freeWeight("Dumbbells", isActive: true),
            freeWeight("Kettlebells", isActive: true),
            freeWeight("Dumbbell Rack", id: "rack", isActive: false)
        ])

        screen.presenter.filter = .selected
        screen.presenter.searchQuery = "dumbbell"

        #expect(screen.presenter.filteredFreeWeights.map(\.wrappedValue.name) == ["Dumbbells"])
    }

    // MARK: - Editing through a binding

    /// The rule the sorting makes easy to get wrong: a row's binding has to reach the item it
    /// displays, not the item that happens to sit at the same index in the profile.
    @Test("Test A Row's Binding Writes Back To The Right Item")
    func testARowsBindingWritesBackToTheRightItem() throws {
        let screen = makeScreen(freeWeights: [
            freeWeight("Kettlebells", id: "kettlebells"),
            freeWeight("Dumbbells", id: "dumbbells")
        ])

        // The first row is Dumbbells, which the profile holds second.
        let firstRow = try #require(screen.presenter.filteredFreeWeights.first)
        firstRow.wrappedValue.isActive = true

        #expect(screen.presenter.gymProfile.freeWeights.first { $0.id == "dumbbells" }?.isActive == true)
        #expect(screen.presenter.gymProfile.freeWeights.first { $0.id == "kettlebells" }?.isActive == false)
    }

    /// A binding is written to the profile the presenter holds, so the next read sees the change.
    @Test("Test An Edit Is Visible On The Next Read")
    func testAnEditIsVisibleOnTheNextRead() throws {
        let screen = makeScreen(freeWeights: [freeWeight("Dumbbells")])

        try #require(screen.presenter.filteredFreeWeights.first).wrappedValue.name = "Hex Dumbbells"

        #expect(screen.presenter.filteredFreeWeights.first?.wrappedValue.name == "Hex Dumbbells")
    }

    @Test("Test Pressing A Row Opens Its Editor")
    func testPressingARowOpensItsEditor() throws {
        let screen = makeScreen(freeWeights: [freeWeight("Dumbbells")])

        screen.presenter.onEditFreeWeightPressed(freeWeight: try #require(screen.presenter.filteredFreeWeights.first))

        #expect(screen.router.shown == ["editFreeWeight"])
    }

    // MARK: - Leaving the screen

    /// The screen is pushed inside the Profile sheet, so the sheet can be swiped away from it.
    /// Leaving by any route saves what was changed; it used to save only from its own Back button.
    @Test("Test Leaving An Edited Profile Saves It")
    func testLeavingAnEditedProfileSavesIt() async {
        let screen = makeScreen(name: "Home Gym")
        screen.presenter.gymProfile.name = "Garage Gym"

        screen.presenter.onViewDisappear()
        await settle()

        let names = screen.interactor.savedProfiles.map { $0.name }
        #expect(names == ["Garage Gym"])
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
        #expect(!screen.presenter.hasUnsavedChanges)
    }

    @Test("Test Leaving An Untouched Profile Saves Nothing")
    func testLeavingAnUntouchedProfileSavesNothing() async {
        let screen = makeScreen(name: "Home Gym")

        screen.presenter.onViewDisappear()
        await settle()

        #expect(screen.interactor.savedProfiles.isEmpty)
    }

    /// With no Back button to hang an alert on, an unnamed profile is kept under the name its
    /// title field shows rather than thrown away.
    @Test("Test An Unnamed Profile Is Saved As Untitled")
    func testAnUnnamedProfileIsSavedAsUntitled() async {
        let screen = makeScreen(name: "Home Gym")
        screen.presenter.gymProfile.name = "  "

        screen.presenter.onViewDisappear()
        await settle()

        let names = screen.interactor.savedProfiles.map { $0.name }
        #expect(names == ["Untitled Gym Profile"])
    }

    @Test("Test Saving Is Tracked From Start To Success")
    func testSavingIsTrackedFromStartToSuccess() async {
        let screen = makeScreen()
        screen.presenter.gymProfile.name = "Garage Gym"

        screen.presenter.onViewDisappear()
        await settle()

        #expect(screen.interactor.trackedEventNames == ["GymProfileView_OnDisappear", "GymProfileView_Save_Start", "GymProfileView_Save_Success"])
    }

    /// The screen has gone by the time a save on leaving fails, so it is reported with a toast
    /// and the edit stays marked unsaved.
    @Test("Test A Failed Save On Leaving Is Reported With A Toast")
    func testAFailedSaveOnLeavingIsReportedWithAToast() async {
        let screen = makeScreen()
        screen.interactor.saveError = URLError(.notConnectedToInternet)
        screen.presenter.gymProfile.name = "Garage Gym"

        screen.presenter.onViewDisappear()
        await settle()

        #expect(screen.interactor.trackedEventNames.last == "GymProfileView_Save_Fail")
        #expect(screen.interactor.shownToasts.count == 1)
        #expect(screen.router.alertTitles.isEmpty)
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["error"])
        #expect(screen.presenter.hasUnsavedChanges)
    }

    /// The equipment editors are pushed now, so this screen has already disappeared when they edit
    /// it, and swiping the Profile sheet away from an editor would not save. Edits made under a
    /// pushed editor save by themselves, quietly, and coming back stops that.
    @Test("Test Edits Under A Pushed Editor Save Without Leaving")
    func testEditsUnderAPushedEditorSaveWithoutLeaving() async throws {
        let screen = makeScreen(freeWeights: [freeWeight("Dumbbells")])
        let binding = try #require(screen.presenter.filteredFreeWeights.first)
        screen.presenter.onEditFreeWeightPressed(freeWeight: binding)

        binding.wrappedValue.isActive = true
        #expect(await TestManagers.eventually { !screen.interactor.savedProfiles.isEmpty })

        #expect(screen.interactor.savedProfiles.count == 1)
        #expect(screen.interactor.playedHaptics.isEmpty)
        #expect(!screen.presenter.hasUnsavedChanges)

        screen.presenter.onViewAppear()
        #expect(!screen.presenter.isEditorPushed)
    }

    /// Continuing through onboarding has the same failure: nothing is saved, nothing is routed to,
    /// and the step has no other way forward.
    @Test("Test A Failed Save Blocks Continuing And Says So")
    func testAFailedSaveBlocksContinuingAndSaysSo() async {
        let screen = makeScreen(user: UserModel(userId: "user-1"))
        screen.interactor.saveError = URLError(.notConnectedToInternet)

        screen.presenter.onContinuePressed(delegate: GymProfileDelegate(gymProfile: screen.presenter.gymProfile))
        await settle()

        #expect(screen.router.shown.isEmpty)
        #expect(screen.router.alertTitles == ["Unable to Save Gym Profile"])
    }

    // MARK: - Continuing through onboarding

    /// Continuing makes this the user's gym before moving on, so the next screen knows what
    /// equipment to plan around.
    @Test("Test Continuing Saves The Profile And Makes It The Favourite")
    func testContinuingSavesTheProfileAndMakesItTheFavourite() async {
        let screen = makeScreen(user: UserModel(userId: "user-1"))

        screen.presenter.onContinuePressed(delegate: GymProfileDelegate(gymProfile: screen.presenter.gymProfile))
        await settle()

        #expect(screen.interactor.savedProfiles.count == 1)
        #expect(screen.interactor.favouritedIds == ["gym-1"])
    }

    /// With no user to ask, there is no onboarding step to infer, so nothing is routed to.
    @Test("Test Navigation Needs A User")
    func testNavigationNeedsAUser() {
        let screen = makeScreen(user: nil)

        screen.presenter.handleNavigation()

        #expect(screen.router.shown.isEmpty)
    }

    @Test("Test Navigation Follows The User's Inferred Step")
    func testNavigationFollowsTheUsersInferredStep() {
        let user = UserModel(userId: "user-1")
        let screen = makeScreen(user: user)

        screen.presenter.handleNavigation()

        #expect(screen.router.shown.count == 1)
    }

    // MARK: - The image picker

    @Test("Test Adding An Image Opens The Picker")
    func testAddingAnImageOpensThePicker() {
        let screen = makeScreen()

        #expect(!screen.presenter.isImagePickerPresented)
        screen.presenter.onAddImagePressed()
        #expect(screen.presenter.isImagePickerPresented)
    }

    // MARK: - Analytics

    @Test("Test Appearing And Leaving Are Both Tracked")
    func testAppearingAndLeavingAreBothTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["GymProfileView_OnAppear"])
        #expect(screen.interactor.trackedEventNames == ["GymProfileView_OnDisappear"])
    }

    // MARK: - Custom and duplicate machines

    private static let latPulldown = "cable_lat_pulldown_machine"

    @Test("Test Duplicate Adds A Copy Beside The Original And Opens Nothing")
    func testDuplicateAddsACopyBesideTheOriginalAndOpensNothing() throws {
        let screen = makeScreen()
        let count = screen.presenter.gymProfile.cableMachines.count

        screen.presenter.onDuplicateMachinePressed(in: \.cableMachines, id: Self.latPulldown)

        let machines = screen.presenter.gymProfile.cableMachines
        let index = try #require(machines.firstIndex { $0.id == Self.latPulldown })
        #expect(machines.count == count + 1)
        #expect(machines[index + 1].typeId == Self.latPulldown)
        #expect(machines[index + 1].name == "Cable Lat Pulldown Machine 2")
        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
        #expect(screen.presenter.hasUnsavedChanges)
    }

    @Test("Test A Machine Added As A Catalogue Type Opens Its Stack Editor")
    func testAMachineAddedAsACatalogueTypeOpensItsStackEditor() throws {
        let screen = makeScreen()
        screen.presenter.onAddMachinePressed()
        let delegate = try #require(screen.router.addMachineDelegates.last)

        delegate.onAdd(GymMachineDraft(kind: .cableMachine, name: "Hammer Pulldown", worksAs: Self.latPulldown))

        let machine = try #require(screen.presenter.gymProfile.cableMachines.last)
        #expect(machine.name == "Hammer Pulldown")
        #expect(machine.typeId == Self.latPulldown)
        #expect(machine.isActive)
        #expect(screen.router.shown == ["addMachine", "editStackMachine"])
        #expect(screen.presenter.isEditorPushed)
    }

    @Test("Test A Plate Loaded Machine Of Its Own Opens Its Editor")
    func testAPlateLoadedMachineOfItsOwnOpensItsEditor() throws {
        let screen = makeScreen()

        screen.presenter.addMachine(GymMachineDraft(kind: .plateLoadedMachine, name: "Garage Sled", worksAs: nil))

        let machine = try #require(screen.presenter.gymProfile.plateLoadedMachines.last)
        #expect(machine.name == "Garage Sled")
        #expect(machine.typeId == machine.id)
        #expect(screen.router.shown == ["editPlateLoadedMachine"])
    }

    @Test("Test Deleting A Machine Of The Users Own Asks First")
    func testDeletingAMachineOfTheUsersOwnAsksFirst() throws {
        let screen = makeScreen()
        screen.presenter.onDuplicateMachinePressed(in: \.cableMachines, id: Self.latPulldown)
        let copy = try #require(screen.presenter.gymProfile.cableMachines.first { $0.isCustom })

        screen.presenter.onDeleteMachinePressed(machine: copy)
        #expect(screen.router.alertTitles == ["Delete Machine?"])
        #expect(screen.presenter.gymProfile.cableMachines.contains { $0.id == copy.id })

        screen.presenter.deleteMachine(kind: .cableMachine, id: copy.id)
        #expect(!screen.presenter.gymProfile.cableMachines.contains { $0.id == copy.id })
    }

    @Test("Test A Catalogue Machine Offers No Delete")
    func testACatalogueMachineOffersNoDelete() throws {
        let screen = makeScreen()
        let catalogue = try #require(screen.presenter.gymProfile.cableMachines.first { $0.id == Self.latPulldown })

        screen.presenter.onDeleteMachinePressed(machine: catalogue)
        screen.presenter.deleteMachine(kind: .cableMachine, id: catalogue.id)

        #expect(screen.router.alertTitles.isEmpty)
        #expect(screen.presenter.gymProfile.cableMachines.contains { $0.id == Self.latPulldown })
    }

    /// Rows follow their item by id, so deleting one machine leaves the other rows' bindings on
    /// the machines they showed, not on whatever slid into their place.
    @Test("Test A Row's Binding Follows Its Machine After Another Is Deleted")
    func testARowsBindingFollowsItsMachineAfterAnotherIsDeleted() throws {
        let screen = makeScreen()
        screen.presenter.onDuplicateMachinePressed(in: \.cableMachines, id: Self.latPulldown)
        let copy = try #require(screen.presenter.gymProfile.cableMachines.first { $0.isCustom })
        let index = try #require(screen.presenter.gymProfile.cableMachines.firstIndex { $0.id == copy.id })
        let next = screen.presenter.gymProfile.cableMachines[index + 1]
        let row = try #require(screen.presenter.filteredCableMachines.first { $0.wrappedValue.id == next.id })

        screen.presenter.deleteMachine(kind: .cableMachine, id: copy.id)
        row.wrappedValue.isActive.toggle()

        #expect(row.wrappedValue.id == next.id)
        #expect(screen.presenter.gymProfile.cableMachines.first { $0.id == next.id }?.isActive == !next.isActive)
    }
}

/// The Add Machine form: a kind, a name and, optionally, the catalogue machine it works as.
@MainActor
struct AddGymMachinePresenterTests {

    private func makePresenter(onAdd: @escaping (GymMachineDraft) -> Void = { _ in }) -> (AddGymMachinePresenter, GymEquipmentInteractor) {
        let interactor = GymEquipmentInteractor()
        let presenter = AddGymMachinePresenter(interactor: interactor, router: GymEquipmentRouter(), delegate: AddGymMachineDelegate(onAdd: onAdd))
        return (presenter, interactor)
    }

    @Test("Test A Name Is Needed To Save")
    func testANameIsNeededToSave() {
        var added: [GymMachineDraft] = []
        let (presenter, _) = makePresenter { added.append($0) }

        presenter.name = "   "
        presenter.onSavePressed()

        #expect(!presenter.canSave)
        #expect(added.isEmpty)
    }

    @Test("Test Saving Hands Back The Draft, Trimmed")
    func testSavingHandsBackTheDraft() {
        var added: [GymMachineDraft] = []
        let (presenter, interactor) = makePresenter { added.append($0) }

        presenter.kind = .pinLoadedMachine
        presenter.name = " Hip Abductor 2 "
        presenter.worksAs = presenter.catalogueMachines.first?.ref.equipmentId
        presenter.onSavePressed()

        #expect(added == [GymMachineDraft(kind: .pinLoadedMachine, name: "Hip Abductor 2", worksAs: presenter.catalogueMachines.first?.ref.equipmentId)])
        #expect(interactor.playedHaptics.map { "\($0)" } == ["success"])
    }

    /// "Works as" lists the catalogue of the chosen kind, so changing kind drops a choice from
    /// another kind's list.
    @Test("Test Changing Kind Clears Works As")
    func testChangingKindClearsWorksAs() {
        let (presenter, _) = makePresenter()
        presenter.worksAs = "cable_lat_pulldown_machine"
        #expect(presenter.catalogueMachines.allSatisfy { $0.ref.kind == .cableMachine })

        presenter.kind = .plateLoadedMachine

        #expect(presenter.worksAs == nil)
        #expect(presenter.catalogueMachines.allSatisfy { $0.ref.kind == .plateLoadedMachine })
    }
}
