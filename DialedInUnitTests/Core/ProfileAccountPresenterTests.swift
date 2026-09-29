//
//  ProfileAccountPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import UIKit
@testable import DialedIn

/// The Account screen: the profile the user edits about themselves, and the two irreversible
/// buttons at the bottom of it — Sign Out and Delete Account.
///
/// Everything here is either a write to the one profile other screens read from, or a destruction
/// of it. So the tests care about three things: that a save writes each field into the field it
/// belongs in, that deletion cannot happen without the user confirming it, and that a failure
/// leaves the user where they were rather than half signed out of an account that still exists.
@MainActor
struct ProfileAccountPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, AccountInteractor {
        var auth: UserAuthInfo?
        var currentUser: UserModel?

        private(set) var didSignOut = false
        private(set) var didDeleteAccount = false
        private(set) var didDeleteUserProfile = false
        private(set) var savedData: [[String: any DMCodableSendable]] = []
        private(set) var uploadedImageCount = 0

        var signOutError: Error?
        var deleteAccountError: Error?
        var updateUserError: Error?
        var updateImageError: Error?

        func signOut() async throws {
            if let signOutError { throw signOutError }
            didSignOut = true
        }

        func deleteUserProfile() {
            didDeleteUserProfile = true
        }

        func deleteAccount() async throws {
            if let deleteAccountError { throw deleteAccountError }
            didDeleteAccount = true
        }

        func updateProfileImageUrl(image: PlatformImage) async throws {
            if let updateImageError { throw updateImageError }
            uploadedImageCount += 1
        }

        private(set) var privacyWrites: [Bool] = []
        func updatePrivacy(isPrivate: Bool) async throws { privacyWrites.append(isPrivate) }

        func updateUser(data: [String: any DMCodableSendable]) async throws {
            if let updateUserError { throw updateUserError }
            savedData.append(data)
        }
    }

    /// `switchToOnboardingModule()` and `showAuthView()` are the only methods `AccountRouter`
    /// requires, so they are the only ones a double sees. `dismissScreen`, `dismissEnvironment` and
    /// `showAlert(error:)` are
    /// `GlobalRouter` extensions, dispatched statically, and never reach here — which is why the
    /// failure tests below assert on "did not switch to onboarding" rather than "showed an alert".
    private final class Router: AccountRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var didSwitchToOnboarding = false
        private(set) var authViewShownCount = 0

        func switchToOnboardingModule() {
            didSwitchToOnboarding = true
        }

        func showAuthView() {
            authViewShownCount += 1
        }

        private(set) var editUsernameShownCount = 0

        func showEditUsernameView() {
            editUsernameShownCount += 1
        }

        private(set) var alertTitles: [String] = []

        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    private struct Screen {
        let presenter: AccountPresenter
        let interactor: Interactor
        let router: Router
        let delegate = AccountDelegate()
    }

    private func makeScreen(user: UserModel? = UserModel(userId: "user-1"), isAnonymous: Bool = false) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = user
        interactor.auth = UserAuthInfo(uid: user?.userId ?? "user-1", isAnonymous: isAnonymous)
        let router = Router()
        return Screen(
            presenter: AccountPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// A real one-pixel image, so `UIImage(data:)` succeeds and the upload branch is actually taken.
    private var realImageData: Data {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    private func string(_ data: [String: any DMCodableSendable], _ key: UserModel.CodingKeys) -> String? {
        data[key.rawValue] as? String
    }

    // MARK: - What can be saved

    /// The profile is how the rest of the app addresses the user, so a nameless one is not a
    /// profile. Blank and whitespace-only both count as nameless.
    /// The privacy switch writes on flip, reads the stored value, and defaults to public.
    @Test("Test The Privacy Switch Reads The Profile And Writes On Flip")
    func testThePrivacySwitchReadsTheProfileAndWritesOnFlip() async {
        let screen = makeScreen(user: UserModel(userId: "user-1", isPrivate: true))
        #expect(screen.presenter.isPrivate)
        #expect(makeScreen().presenter.isPrivate == false)

        screen.presenter.isPrivate = false
        await TestManagers.eventually { !screen.interactor.privacyWrites.isEmpty }

        #expect(screen.interactor.privacyWrites == [false])
        #expect(screen.interactor.trackedEventNames.contains("AccountView_Privacy_Toggle"))
    }

    @Test("Test A Profile Cannot Be Saved Without A First Name")
    func testAProfileCannotBeSavedWithoutAFirstName() {
        let screen = makeScreen()

        #expect(!screen.presenter.canSave)
        screen.presenter.firstName = "   "
        #expect(!screen.presenter.canSave)
        screen.presenter.firstName = "Andrew"
        #expect(screen.presenter.canSave)
    }

    @Test("Test Saving Without A Name Writes Nothing")
    func testSavingWithoutANameWritesNothing() async {
        let screen = makeScreen()

        await screen.presenter.saveProfile()

        #expect(screen.interactor.savedData.isEmpty)
    }

    // MARK: - Prefill

    /// The screen edits an existing profile, so opening it has to show what is stored. A field that
    /// came up empty would be saved back empty and quietly wipe what was there.
    @Test("Test Opening The Screen Shows The Stored Profile")
    func testOpeningTheScreenShowsTheStoredProfile() {
        let birthday = Date(timeIntervalSince1970: 500_000_000)
        let screen = makeScreen(user: UserModel(
            userId: "user-1",
            firstName: "Andrew",
            lastName: "Coyle",
            submittedDateOfBirth: birthday,
            submittedGender: .male,
            submittedHeightCentimeters: 182.5,
            submittedExerciseFrequency: .threeToFour,
            submittedCardioFitnessLevel: .intermediate
        ))

        screen.presenter.prefillFromCurrentUser()

        #expect(screen.presenter.firstName == "Andrew")
        #expect(screen.presenter.lastName == "Coyle")
        #expect(screen.presenter.dateOfBirth == birthday)
        #expect(screen.presenter.selectedGender == .male)
        #expect(screen.presenter.heightText == "182.5")
        #expect(screen.presenter.selectedExerciseFrequency == .threeToFour)
        #expect(screen.presenter.selectedCardioFitnessLevel == .intermediate)
    }

    /// Nothing stored means nothing to prefill — in particular the date of birth keeps its "today"
    /// placeholder rather than being reset to the epoch.
    @Test("Test Prefilling Without A User Leaves The Fields Alone")
    func testPrefillingWithoutAUserLeavesTheFieldsAlone() {
        let screen = makeScreen(user: nil)
        let placeholder = screen.presenter.dateOfBirth

        screen.presenter.prefillFromCurrentUser()

        #expect(screen.presenter.firstName.isEmpty)
        #expect(screen.presenter.dateOfBirth == placeholder)
    }

    // MARK: - Height

    /// Height is typed rather than picked, so the field has to cope with what a keyboard produces.
    /// Anything that is not a positive number reads as "leave it alone", never as zero.
    @Test("Test Height Only Counts When It Is A Positive Number")
    func testHeightOnlyCountsWhenItIsAPositiveNumber() {
        let screen = makeScreen()

        for text in ["", "   ", "abc", "0", "-4"] {
            screen.presenter.heightText = text
            #expect(screen.presenter.heightCentimeters == nil, "\"\(text)\" should not be a height")
        }

        screen.presenter.heightText = " 182.5 "
        #expect(screen.presenter.heightCentimeters == 182.5)
    }

    /// A height that came back from the profile has to survive being shown and saved again
    /// unchanged. Formatting it for display and re-parsing it is the round trip that could lose it.
    @Test("Test A Stored Height Survives A Round Trip Through The Field")
    func testAStoredHeightSurvivesARoundTripThroughTheField() async {
        let screen = makeScreen(user: UserModel(userId: "user-1", firstName: "Andrew", submittedHeightCentimeters: 182.5))
        screen.presenter.prefillFromCurrentUser()

        await screen.presenter.saveProfile()

        let saved = screen.interactor.savedData.first
        #expect(saved?[UserModel.CodingKeys.submittedHeightCentimeters.rawValue] as? Double == 182.5)
    }

    /// Clearing the field does not clear the stored height — there is no "no height" state in the
    /// profile, and writing zero would make every calorie estimate that reads it nonsense.
    @Test("Test An Empty Height Field Does Not Overwrite The Stored Height")
    func testAnEmptyHeightFieldDoesNotOverwriteTheStoredHeight() async {
        let screen = makeScreen()
        screen.presenter.firstName = "Andrew"
        screen.presenter.heightText = ""

        await screen.presenter.saveProfile()

        let saved = screen.interactor.savedData.first
        #expect(saved?[UserModel.CodingKeys.submittedHeightCentimeters.rawValue] == nil)
    }

    // MARK: - Saving

    /// Each field has to land in its own key. This used to write the gender into
    /// `submittedFirstName`, so saving a profile with a gender picked replaced the user's name with
    /// "male" everywhere it is shown.
    @Test("Test Every Field Is Saved Under Its Own Key")
    func testEveryFieldIsSavedUnderItsOwnKey() async {
        let screen = makeScreen()
        screen.presenter.firstName = "Andrew"
        screen.presenter.lastName = "Coyle"
        screen.presenter.selectedGender = .male
        screen.presenter.selectedCardioFitnessLevel = .advanced
        screen.presenter.selectedExerciseFrequency = .fiveToSix

        await screen.presenter.saveProfile()

        let saved = screen.interactor.savedData.first
        #expect(string(saved ?? [:], .submittedFirstName) == "Andrew")
        #expect(string(saved ?? [:], .submittedLastName) == "Coyle")
        #expect(string(saved ?? [:], .submittedGender) == Gender.male.rawValue)
        #expect(string(saved ?? [:], .submittedCardioFitnessLevel) == CardioFitnessLevel.advanced.rawValue)
        #expect(string(saved ?? [:], .submittedExerciseFrequency) == ExerciseFrequency.fiveToSix.rawValue)
    }

    /// A name typed with a trailing space is still that name. Storing the space would show up in
    /// every greeting and in the follower lists other people see.
    @Test("Test Names Are Trimmed Before They Are Saved")
    func testNamesAreTrimmedBeforeTheyAreSaved() async {
        let screen = makeScreen()
        screen.presenter.firstName = "  Andrew "
        screen.presenter.lastName = " Coyle  "

        await screen.presenter.saveProfile()

        #expect(string(screen.interactor.savedData.first ?? [:], .submittedFirstName) == "Andrew")
        #expect(string(screen.interactor.savedData.first ?? [:], .submittedLastName) == "Coyle")
    }

    /// The optional pickers start unset for anyone who skipped them in onboarding. Leaving them
    /// unset must not write a default over what is already stored.
    @Test("Test Unset Pickers Are Left Out Of The Save")
    func testUnsetPickersAreLeftOutOfTheSave() async {
        let screen = makeScreen()
        screen.presenter.firstName = "Andrew"

        await screen.presenter.saveProfile()

        let saved = screen.interactor.savedData.first
        #expect(saved?[UserModel.CodingKeys.submittedGender.rawValue] == nil)
        #expect(saved?[UserModel.CodingKeys.submittedCardioFitnessLevel.rawValue] == nil)
        #expect(saved?[UserModel.CodingKeys.submittedExerciseFrequency.rawValue] == nil)
    }

    @Test("Test A Successful Save Is Tracked")
    func testASuccessfulSaveIsTracked() async {
        let screen = makeScreen()
        screen.presenter.firstName = "Andrew"

        await screen.presenter.saveProfile()

        #expect(screen.interactor.trackedEventNames.contains("profile_edit_save_success"))
        #expect(!screen.presenter.isSaving)
    }

    /// A failed save must not look like a successful one. The screen stays put, the spinner stops,
    /// and the failure is recorded — the alert itself goes out through a `GlobalRouter` extension
    /// and cannot be observed from here.
    @Test("Test A Failed Save Is Reported And Stops Saving")
    func testAFailedSaveIsReportedAndStopsSaving() async {
        let screen = makeScreen()
        screen.presenter.firstName = "Andrew"
        screen.interactor.updateUserError = URLError(.networkConnectionLost)

        await screen.presenter.saveProfile()

        #expect(screen.interactor.trackedEventNames.contains("profile_edit_save_failed"))
        #expect(!screen.interactor.trackedEventNames.contains("profile_edit_save_success"))
        #expect(!screen.presenter.isSaving)
    }

    // MARK: - Profile photo

    @Test("Test A Chosen Photo Is Uploaded Alongside The Profile")
    func testAChosenPhotoIsUploadedAlongsideTheProfile() async {
        let screen = makeScreen()
        screen.presenter.firstName = "Andrew"
        screen.presenter.selectedImageData = realImageData

        await screen.presenter.saveProfile()

        #expect(screen.interactor.uploadedImageCount == 1)
        #expect(screen.interactor.savedData.count == 1)
    }

    /// A new photo is an upload, so offline the save does not start.
    @Test("Test Offline A New Photo Says You're Offline And Saves Nothing")
    func testOfflineANewPhotoSaysYoureOfflineAndSavesNothing() async {
        let screen = makeScreen()
        screen.interactor.isOffline = true
        screen.presenter.firstName = "Andrew"
        screen.presenter.selectedImageData = realImageData

        await screen.presenter.saveProfile()

        #expect(screen.router.alertTitles == [OfflineError.title])
        #expect(screen.interactor.uploadedImageCount == 0)
        #expect(screen.interactor.savedData.isEmpty)
        #expect(!screen.presenter.isSaving)
    }

    /// Without a photo it is a queued Firestore write, which the user listener shows at once, so
    /// offline the save completes without waiting for the server to acknowledge it.
    @Test("Test Offline A Profile Edit Is Queued Without Waiting")
    func testOfflineAProfileEditIsQueuedWithoutWaiting() async {
        let screen = makeScreen()
        screen.interactor.isOffline = true
        screen.presenter.firstName = "Andrew"

        await screen.presenter.saveProfile()

        #expect(screen.router.alertTitles.isEmpty)
        #expect(!screen.presenter.isSaving)
        #expect(await TestManagers.eventually { screen.interactor.savedData.count == 1 })
    }

    /// Saving without touching the photo must not re-upload anything — the existing picture stays
    /// as it is rather than being replaced by whatever the picker last held.
    @Test("Test Saving Without A New Photo Uploads Nothing")
    func testSavingWithoutANewPhotoUploadsNothing() async {
        let screen = makeScreen()
        screen.presenter.firstName = "Andrew"

        await screen.presenter.saveProfile()

        #expect(screen.interactor.uploadedImageCount == 0)
        #expect(screen.interactor.savedData.count == 1)
    }

    @Test("Test The Image Picker Opens On Request")
    func testTheImagePickerOpensOnRequest() {
        let screen = makeScreen()

        screen.presenter.presentImagePicker()

        #expect(screen.presenter.isImagePickerPresented)
    }

    // MARK: - Upgrading an anonymous account

    /// Signing an anonymous account out is irreversible — there is no credential to sign back in
    /// with — so that account is offered the upgrade in place of Log Out. This was the only screen
    /// in the app offering it, and it was on a screen nothing navigated to.
    @Test("Test An Anonymous Account Is Offered The Upgrade Instead Of Log Out")
    func testAnAnonymousAccountIsOfferedTheUpgradeInsteadOfLogOut() {
        #expect(makeScreen(isAnonymous: true).presenter.isAnonymousUser)
        #expect(!makeScreen(isAnonymous: false).presenter.isAnonymousUser)
    }

    /// The upgrade goes to the same `AuthView` onboarding uses, which links a credential to the
    /// signed-in anonymous user rather than replacing it, so the data logged so far survives.
    @Test("Test Saving An Anonymous Account Opens Sign In")
    func testSavingAnAnonymousAccountOpensSignIn() {
        let screen = makeScreen(isAnonymous: true)

        screen.presenter.onSaveAccountPressed()

        #expect(screen.router.authViewShownCount == 1)
        #expect(!screen.interactor.didSignOut)
        #expect(screen.interactor.trackedEventNames == ["Settings_SaveAccount_Press"])
    }

    // MARK: - Sign out

    /// Signing out has to actually sign out and then put the user back on the onboarding module.
    /// Leaving them on a settings screen belonging to an account they no longer hold is the
    /// half-state this guards against.
    @Test("Test Signing Out Signs Out And Returns To Onboarding")
    func testSigningOutSignsOutAndReturnsToOnboarding() async {
        let screen = makeScreen()

        screen.presenter.onSignOutPressed()

        await TestManagers.eventually { screen.router.didSwitchToOnboarding }
        #expect(screen.interactor.didSignOut)
        #expect(screen.interactor.trackedEventNames.contains("Settings_SignOut_Success"))
    }

    /// A sign-out that fails leaves the user signed in. Switching to onboarding anyway would show
    /// the welcome flow to someone whose session is still live, and the next screen they reach
    /// would be full of their data again.
    @Test("Test A Failed Sign Out Leaves The User Signed In")
    func testAFailedSignOutLeavesTheUserSignedIn() async {
        let screen = makeScreen()
        screen.interactor.signOutError = URLError(.networkConnectionLost)

        screen.presenter.onSignOutPressed()

        await TestManagers.eventually { screen.interactor.trackedEventNames.contains("Settings_SignOut_Fail") }
        #expect(!screen.router.didSwitchToOnboarding)
        #expect(!screen.interactor.didSignOut)
        #expect(!screen.interactor.trackedEventNames.contains("Settings_SignOut_Success"))
    }

    // MARK: - Delete account

    /// The whole point of the confirmation. Pressing Delete Account raises the alert and does
    /// nothing else — the account, and everything logged against it, is still there.
    ///
    /// The alert goes out through `showAlert(title:subtitle:buttons:)`, a `GlobalRouter` extension
    /// that dispatches statically and so never reaches the double. That it appeared cannot be
    /// asserted here; that nothing was destroyed can, and that is the half that protects the user.
    @Test("Test Pressing Delete Account Destroys Nothing Until Confirmed")
    func testPressingDeleteAccountDestroysNothingUntilConfirmed() async {
        let screen = makeScreen()

        screen.presenter.onDeleteAccountPressed()

        #expect(!screen.interactor.didDeleteAccount)
        #expect(!screen.router.didSwitchToOnboarding)
        #expect(screen.interactor.trackedEventNames == ["Settings_DeleteAccount_Start"])
        #expect(!screen.interactor.trackedEventNames.contains("Settings_DeleteAccount_StartConfirm"))
    }

    @Test("Test Confirming Deletion Deletes The Account And Returns To Onboarding")
    func testConfirmingDeletionDeletesTheAccountAndReturnsToOnboarding() async {
        let screen = makeScreen()

        screen.presenter.onDeleteAccountConfirmed()

        await TestManagers.eventually { screen.router.didSwitchToOnboarding }
        #expect(screen.interactor.didDeleteAccount)
        #expect(screen.interactor.trackedEventNames.contains("Settings_DeleteAccount_StartConfirm"))
        #expect(screen.interactor.trackedEventNames.contains("Settings_DeleteAccount_Success"))
    }

    /// A deletion that fails is the worst half-state available: the account still exists, so the
    /// user must stay in it rather than be dropped onto onboarding with no way back to the data
    /// that was not deleted after all.
    @Test("Test A Failed Deletion Leaves The User In Their Account")
    func testAFailedDeletionLeavesTheUserInTheirAccount() async {
        let screen = makeScreen()
        screen.interactor.deleteAccountError = URLError(.networkConnectionLost)

        screen.presenter.onDeleteAccountConfirmed()

        await TestManagers.eventually { screen.interactor.trackedEventNames.contains("Settings_DeleteAccount_Fail") }
        #expect(!screen.router.didSwitchToOnboarding)
        #expect(!screen.interactor.didDeleteAccount)
        #expect(!screen.interactor.trackedEventNames.contains("Settings_DeleteAccount_Success"))
    }

    // MARK: - Tracking

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: screen.delegate)
        screen.presenter.onViewDisappear(delegate: screen.delegate)

        #expect(screen.interactor.trackedScreenEventNames == ["AccountView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["AccountView_Disappear"])
    }

    // MARK: - Usernames

    @Test("Test The Username Row Opens The Editor")
    func testTheUsernameRowOpensTheEditor() {
        let screen = makeScreen()

        screen.presenter.onUsernamePressed()

        #expect(screen.router.editUsernameShownCount == 1)
        #expect(screen.interactor.trackedEventNames == ["AccountView_Username_Press"])
    }
}
