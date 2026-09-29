//
//  GymProfilesListPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The list of gyms, and the screen that names a new one.
///
/// A user can keep several gyms — a commercial one, a home rack, a hotel gym — and one of them is
/// marked as the usual. That mark lives on the user rather than on the gym, so the list has to
/// resolve it back and take care not to show the same gym twice: once as the favourite at the top
/// and again in the list below it.
@MainActor
struct GymProfilesListPresenterTests {

    private final class Interactor: SpyGlobalInteractor, GymProfilesInteractor {
        var userId: String?
        var currentUser: UserModel?
        var gymProfiles: [GymProfileModel] = []

        private(set) var deletedIds: [String] = []
        private(set) var favouritedIds: [String?] = []
        var deleteError: Error?
        var favouriteError: Error?

        func updateFavouriteGymProfileId(profileId: String?) async throws {
            if let favouriteError { throw favouriteError }
            favouritedIds.append(profileId)
        }

        func deleteGymProfile(_ profileId: String) async throws {
            if let deleteError { throw deleteError }
            deletedIds.append(profileId)
        }
    }

    private final class Router: GymProfilesRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var openedProfiles: [GymProfileModel] = []

        /// Bound on the class declaring the conformance, or the protocol's default implementation
        /// runs and the alert escapes to the real router unseen.
        private(set) var alertTitles: [String] = []

        func showAlert(error: Error) { alertTitles.append("Error") }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }

        func showGymProfileView(delegate: GymProfileDelegate) {
            openedProfiles.append(delegate.gymProfile)
        }
    }

    private struct Screen {
        let presenter: GymProfilesPresenter
        let interactor: Interactor
        let router: Router
    }

    private struct TestError: Error { }

    private func gym(_ id: String, name: String) -> GymProfileModel {
        GymProfileModel(id: id, authorId: "user-1", name: name)
    }

    private func makeScreen(
        profiles: [GymProfileModel] = [],
        favouriteId: String? = nil,
        userId: String? = "user-1"
    ) -> Screen {
        let interactor = Interactor()
        interactor.userId = userId
        interactor.gymProfiles = profiles
        interactor.currentUser = userId.map {
            UserModel(userId: $0, submittedFavouriteGymProfileId: favouriteId)
        }
        let router = Router()
        return Screen(
            presenter: GymProfilesPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// Saving happens in a detached `Task`, so a test has to let the loop turn before asserting.
    private func settle() async {
        for _ in 0..<10 {
            await Task.yield()
        }
    }

    // MARK: - What the list shows

    @Test("Test Every Gym Is Counted")
    func testEveryGymIsCounted() {
        let screen = makeScreen(profiles: [gym("a", name: "Commercial"), gym("b", name: "Home")])

        #expect(screen.presenter.numGyms == 2)
    }

    /// The favourite is named on the user, so the list has to find the gym it points at.
    @Test("Test The Favourite Gym Is Resolved From The User")
    func testTheFavouriteGymIsResolvedFromTheUser() {
        let screen = makeScreen(
            profiles: [gym("a", name: "Commercial"), gym("b", name: "Home")],
            favouriteId: "b"
        )

        #expect(screen.presenter.favouriteGymProfileId == "b")
        #expect(screen.presenter.favouriteGymProfile?.name == "Home")
    }

    /// The favourite is shown on its own, so leaving it in the list below would show it twice.
    @Test("Test The Favourite Is Not Listed Again Below")
    func testTheFavouriteIsNotListedAgainBelow() {
        let screen = makeScreen(
            profiles: [gym("a", name: "Commercial"), gym("b", name: "Home")],
            favouriteId: "b"
        )

        #expect(screen.presenter.nonFavouriteGymProfiles.map(\.id) == ["a"])
    }

    /// With no favourite chosen, every gym belongs in the list rather than none of them.
    @Test("Test With No Favourite Every Gym Is Listed")
    func testWithNoFavouriteEveryGymIsListed() {
        let screen = makeScreen(profiles: [gym("a", name: "Commercial"), gym("b", name: "Home")])

        #expect(screen.presenter.favouriteGymProfile == nil)
        #expect(screen.presenter.nonFavouriteGymProfiles.count == 2)
    }

    /// A favourite pointing at a gym that has since been deleted leaves nothing marked, and still
    /// must not hide one of the gyms that remain.
    @Test("Test A Favourite That No Longer Exists Hides Nothing")
    func testAFavouriteThatNoLongerExistsHidesNothing() {
        let screen = makeScreen(profiles: [gym("a", name: "Commercial")], favouriteId: "deleted")

        #expect(screen.presenter.favouriteGymProfile == nil)
        #expect(screen.presenter.nonFavouriteGymProfiles.count == 1)
    }

    // MARK: - Opening a gym

    @Test("Test Tapping A Gym Opens That Gym")
    func testTappingAGymOpensThatGym() {
        let screen = makeScreen(profiles: [gym("a", name: "Commercial"), gym("b", name: "Home")])

        screen.presenter.onGymProfilePressed(gymProfile: gym("b", name: "Home"))

        #expect(screen.router.openedProfiles.map(\.id) == ["b"])
    }

    /// A new gym is opened blank but already belongs to the signed-in user, or it would save with
    /// no owner and never come back.
    @Test("Test Adding A Gym Opens A Blank One Owned By The User")
    func testAddingAGymOpensABlankOneOwnedByTheUser() {
        let screen = makeScreen()

        screen.presenter.onAddGymProfilePressed()

        #expect(screen.router.openedProfiles.count == 1)
        #expect(screen.router.openedProfiles.first?.authorId == "user-1")
        #expect(screen.router.openedProfiles.first?.name.isEmpty == true)
    }

    @Test("Test Adding A Gym Does Nothing Without A Signed In User")
    func testAddingAGymDoesNothingWithoutASignedInUser() {
        let screen = makeScreen(userId: nil)

        screen.presenter.onAddGymProfilePressed()

        #expect(screen.router.openedProfiles.isEmpty)
    }

    // MARK: - Deleting and favouriting

    /// Swiping to Delete used to delete the gym on the spot. It asks first, and nothing is deleted
    /// until the user confirms.
    @Test("Test Deleting A Gym Asks Before Deleting")
    func testDeletingAGymAsksBeforeDeleting() async {
        let screen = makeScreen(profiles: [gym("a", name: "Commercial")])

        screen.presenter.onDeleteGymProfilePressed(profile: gym("a", name: "Commercial"))
        await settle()

        #expect(screen.router.alertTitles == ["Delete Gym Profile?"])
        #expect(screen.interactor.deletedIds.isEmpty)
    }

    @Test("Test Deleting A Gym Deletes That Gym")
    func testDeletingAGymDeletesThatGym() async {
        let screen = makeScreen(profiles: [gym("a", name: "Commercial")])

        screen.presenter.deleteGymProfile(profile: gym("a", name: "Commercial"))
        await settle()

        #expect(screen.interactor.deletedIds == ["a"])
        #expect(screen.interactor.trackedEventNames.contains("GymProfilesView_DeleteProfile_Success"))
    }

    /// A delete that fails is logged as a failure rather than reported as done, since the gym is
    /// still there afterwards.
    @Test("Test A Failed Delete Is Recorded As A Failure")
    func testAFailedDeleteIsRecordedAsAFailure() async {
        let screen = makeScreen(profiles: [gym("a", name: "Commercial")])
        screen.interactor.deleteError = TestError()

        screen.presenter.deleteGymProfile(profile: gym("a", name: "Commercial"))
        await settle()

        #expect(screen.interactor.trackedEventNames.contains("GymProfilesView_DeleteProfile_Fail"))
        #expect(!screen.interactor.trackedEventNames.contains("GymProfilesView_DeleteProfile_Success"))
    }

    /// And said out loud: the gym is still in the list afterwards, which on its own reads as a
    /// swipe that did not take.
    @Test("Test A Failed Delete Is Reported To The User")
    func testAFailedDeleteIsReportedToTheUser() async {
        let screen = makeScreen(profiles: [gym("a", name: "Commercial")])
        screen.interactor.deleteError = TestError()

        screen.presenter.deleteGymProfile(profile: gym("a", name: "Commercial"))
        await settle()

        #expect(screen.router.alertTitles == ["Unable to delete gym profile"])
    }

    /// The usual gym is what a new workout is filled in against, so marking one has to reach the
    /// user's profile rather than only the row's star.
    @Test("Test Favouriting A Gym Records It Against The User")
    func testFavouritingAGymRecordsItAgainstTheUser() async {
        let screen = makeScreen(profiles: [gym("a", name: "Commercial"), gym("b", name: "Home")])

        screen.presenter.favouriteGymProfile(profile: gym("b", name: "Home"))
        await settle()

        #expect(screen.interactor.favouritedIds == ["b"])
        #expect(screen.interactor.trackedEventNames.contains("GymProfilesView_FavouriteGymProfile_Success"))
    }

    @Test("Test A Failed Favourite Is Recorded As A Failure")
    func testAFailedFavouriteIsRecordedAsAFailure() async {
        let screen = makeScreen(profiles: [gym("a", name: "Commercial")])
        screen.interactor.favouriteError = TestError()

        screen.presenter.favouriteGymProfile(profile: gym("a", name: "Commercial"))
        await settle()

        #expect(screen.interactor.trackedEventNames.contains("GymProfilesView_FavouriteGymProfile_Fail"))
        #expect(screen.router.alertTitles == ["Unable to set your usual gym"])
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["GymProfilesView_Appear"])
    }
}

/// Naming a new gym, the first step of setting one up — reached both from the gym list and from
/// onboarding.
@MainActor
struct GymCreateProfilePresenterTests {

    private final class Interactor: SpyGlobalInteractor, CreateGymProfileInteractor {
        var userId: String? = "user-1"
    }

    private final class Router: CreateGymProfileRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var openedProfiles: [GymProfileModel] = []
        private(set) var openedDelegates: [GymProfileDelegate] = []

        func showGymProfileView(delegate: GymProfileDelegate) {
            openedProfiles.append(delegate.gymProfile)
            openedDelegates.append(delegate)
        }
    }

    /// Main-actor isolated so it is `Sendable` for the completion closure the delegate carries.
    @MainActor
    private final class CompletionBox {
        var completed = false
    }

    private struct Screen {
        let presenter: CreateGymProfilePresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(userId: String? = "user-1") -> Screen {
        let interactor = Interactor()
        interactor.userId = userId
        let router = Router()
        return Screen(
            presenter: CreateGymProfilePresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// A gym with no name cannot be told from the others in the list, so the button stays off until
    /// there is one.
    @Test("Test A Gym Needs A Name Before It Can Be Created")
    func testAGymNeedsANameBeforeItCanBeCreated() {
        let screen = makeScreen()

        #expect(!screen.presenter.canSave)

        screen.presenter.gymProfileName = "Home Gym"

        #expect(screen.presenter.canSave)
    }

    @Test("Test An Unnamed Gym Does Not Move On")
    func testAnUnnamedGymDoesNotMoveOn() {
        let screen = makeScreen()

        screen.presenter.onContinuePressed(oldDelegate: CreateGymProfileDelegate())

        #expect(screen.router.openedProfiles.isEmpty)
    }

    /// The name typed here is the one the equipment screen opens on — losing it would leave the
    /// user naming the gym twice.
    @Test("Test The Typed Name Carries Into The New Gym")
    func testTheTypedNameCarriesIntoTheNewGym() {
        let screen = makeScreen()
        screen.presenter.gymProfileName = "Home Gym"

        screen.presenter.onContinuePressed(oldDelegate: CreateGymProfileDelegate())

        #expect(screen.router.openedProfiles.first?.name == "Home Gym")
        #expect(screen.router.openedProfiles.first?.authorId == "user-1")
    }

    @Test("Test A Gym Is Not Created Without A Signed In User")
    func testAGymIsNotCreatedWithoutASignedInUser() {
        let screen = makeScreen(userId: nil)
        screen.presenter.gymProfileName = "Home Gym"

        screen.presenter.onContinuePressed(oldDelegate: CreateGymProfileDelegate())

        #expect(screen.router.openedProfiles.isEmpty)
    }

    /// This screen is a step of onboarding as well as a standalone one, and onboarding is waiting
    /// on the completion the caller handed in. Dropping it would strand the user on the gym screen
    /// with no way back into the flow.
    @Test("Test Onboarding Is Told When The Gym Is Finished")
    func testOnboardingIsToldWhenTheGymIsFinished() {
        let screen = makeScreen()
        screen.presenter.gymProfileName = "Home Gym"
        let box = CompletionBox()

        screen.presenter.onContinuePressed(oldDelegate: CreateGymProfileDelegate(onComplete: { box.completed = true }))
        screen.router.openedDelegates.first?.onCompleted?()

        #expect(box.completed)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: CreateGymProfileDelegate())

        #expect(screen.interactor.trackedScreenEventNames == ["CreateGymProfileView_Appear"])
    }
}
