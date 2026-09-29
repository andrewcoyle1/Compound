//
//  GymProfilePresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The gym profile: which equipment a gym has, across eleven kinds of it.
///
/// The screen shows each kind as a searchable, filterable list, and every row is editable in place.
/// That is the awkward part: the rows are sorted by name but the bindings have to write back to the
/// item's position in the *unsorted* array. Handing a row the binding for its display position
/// instead would let a user edit one dumbbell and change another, which is why the write-back is
/// pinned here rather than left to the view.
///
/// A profile with no name cannot be saved, so leaving the screen asks before discarding it.
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
        func showEditCableMachineView(cableMachine: Binding<CableMachine>) { record("editCableMachine") }
        func showEditPlateLoadedMachineView(plateLoadedMachine: Binding<PlateLoadedMachine>) { record("editPlateLoadedMachine") }
        func showEditPinLoadedMachineView(pinLoadedMachine: Binding<PinLoadedMachine>) { record("editPinLoadedMachine") }
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

    @Test("Test Leaving A Named Profile Saves It")
    func testLeavingANamedProfileSavesIt() async {
        let screen = makeScreen(name: "Home Gym")

        screen.presenter.onBackButtonPressed()
        await settle()

        #expect(screen.interactor.savedProfiles.map(\.name) == ["Home Gym"])
    }

    /// An unnamed profile cannot be saved, so leaving asks rather than silently dropping the work.
    @Test("Test Leaving An Unnamed Profile Saves Nothing")
    func testLeavingAnUnnamedProfileSavesNothing() async {
        let screen = makeScreen(name: "")

        screen.presenter.onBackButtonPressed()
        await settle()

        #expect(screen.interactor.savedProfiles.isEmpty)
    }

    @Test("Test Saving Is Tracked From Start To Success")
    func testSavingIsTrackedFromStartToSuccess() async {
        let screen = makeScreen()

        screen.presenter.onBackButtonPressed()
        await settle()

        #expect(screen.interactor.trackedEventNames == ["GymProfileView_Save_Start", "GymProfileView_Save_Success"])
    }

    @Test("Test A Failed Save Is Tracked As A Failure")
    func testAFailedSaveIsTrackedAsAFailure() async {
        let screen = makeScreen()
        screen.interactor.saveError = URLError(.notConnectedToInternet)

        screen.presenter.onBackButtonPressed()
        await settle()

        #expect(screen.interactor.trackedEventNames.last == "GymProfileView_Save_Fail")
    }

    /// Saving is what dismisses this screen, so a failed save leaves the user on it. Without an
    /// alert the Back button simply looks broken.
    @Test("Test A Failed Save Tells The User Why The Screen Did Not Close")
    func testAFailedSaveTellsTheUserWhyTheScreenDidNotClose() async {
        let screen = makeScreen()
        screen.interactor.saveError = URLError(.notConnectedToInternet)

        screen.presenter.onBackButtonPressed()
        await settle()

        #expect(screen.router.alertTitles == ["Unable to Save Gym Profile"])
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
}
