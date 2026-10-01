//
//  OnboardingAccountSetupPresenterTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import Compound

// The first half of "complete your account": name and photo, gender, date of birth and height.
//
// Only the name is written to the profile here. Gender, date of birth and height are carried
// forward on a chain of delegate structs and are not persisted until the expenditure screen at the
// end of the flow, so a field dropped on any hop is lost in silence — the user is not asked again
// and ends up with a calorie target computed from someone else's numbers.
//
// `HeightPresenter`'s centimetre/inch conversions are covered separately, in
// `OnboardingHeightConversionTests`.

// MARK: - Shared fixtures

/// A fixed birth date. Anything derived from `Date()` could sit on a boundary the day the suite
/// runs, and a date that is emphatically not the screen's default is the only way to tell a value
/// that travelled from one that was never set.
private let onboardingBirthDate = Calendar.current.date(
    from: DateComponents(year: 1988, month: 3, day: 14)
) ?? Date(timeIntervalSince1970: 574_473_600)

/// The delegate the height step receives: everything the two steps before it collected.
@MainActor
private func heightDelegate(gender: Gender = .female) -> HeightDelegate {
    HeightDelegate(delegate: DateOfBirthDelegate(gender: gender), dateOfBirth: onboardingBirthDate)
}

/// A one-pixel image, encoded the way `PhotosPickerItem` hands one over: as `Data` the presenter
/// has to decode itself before it can upload anything.
@MainActor
private func onePixelPNGData() -> Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
    return renderer.image { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    }.pngData() ?? Data()
}

// MARK: - The screen that starts account setup

/// A single Continue button holding no state, so the only thing it can get wrong is going somewhere
/// other than the first question.
@MainActor
struct OnboardingAccountSetupPresenterTests {

    private final class Interactor: SpyGlobalInteractor, CompleteAccountSetupInteractor { }

    private final class Router: SpyOnboardingRouter, CompleteAccountSetupRouter {
        func showNamePhotoView() { record("namePhoto") }
        func showDevSettingsView() { record("devSettings") }
    }

    @Test("Starting account setup opens the name step")
    func testStartingAccountSetupOpensTheNameStep() {
        let interactor = Interactor()
        let router = Router()
        let sut = CompleteAccountSetupPresenter(interactor: interactor, router: router)

        sut.handleNavigation()

        #expect(router.shown == ["namePhoto"])
        #expect(interactor.trackedEventNames == ["CompleteAccountSetup_Navigate"])
    }
}

// MARK: - Step 1: name and photo

/// The only free-text field in onboarding and the only account-setup answer written to the profile
/// as it is entered. A name lost here leaves every later greeting blank.
@MainActor
struct OnboardingNamePhotoPresenterTests {

    private final class Interactor: SpyGlobalInteractor, NamePhotoInteractor {
        let currentUser: UserModel?
        var nameSaveError: Error?
        var imageUploadError: Error?
        private(set) var savedNames: [(first: String?, last: String?)] = []
        private(set) var uploadedImageCount = 0

        init(currentUser: UserModel? = nil) {
            self.currentUser = currentUser
        }

        func updateUserName(firstName: String?, lastName: String?) async throws {
            if let nameSaveError { throw nameSaveError }
            savedNames.append((firstName, lastName))
        }

        func updateProfileImageUrl(image: PlatformImage) async throws {
            if let imageUploadError { throw imageUploadError }
            uploadedImageCount += 1
        }
    }

    /// `showLoadingModal()` and `dismissModal()` are `GlobalRouter` extension methods with no
    /// protocol requirement behind them, so they are dispatched statically and run against the mock
    /// `AnyRouter` rather than reaching this double. The alerts are requirements, and
    /// `SpyOnboardingRouter` is where their witness is bound — see the comment on that class.
    private final class Router: SpyOnboardingRouter, NamePhotoRouter {
        func showGenderView() { record("gender") }
        func showDevSettingsView() { record("devSettings") }
    }

    private struct Screen {
        let presenter: NamePhotoPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(user: UserModel? = nil) -> Screen {
        let interactor = Interactor(currentUser: user)
        let router = Router()
        return Screen(
            presenter: NamePhotoPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// A name of spaces would clear an `isEmpty` check and leave the app greeting nobody.
    @Test("A first name of nothing but whitespace does not count as a name")
    func testAFirstNameOfOnlyWhitespaceIsNotAName() {
        let sut = makeScreen().presenter

        #expect(!sut.canContinue)

        sut.firstName = "   \n "
        #expect(!sut.canContinue)

        sut.firstName = "Ada"
        #expect(sut.canContinue)
    }

    /// A last name is optional: plenty of people have one name, and demanding a second would wall
    /// them out of the flow entirely.
    @Test("A first name on its own is enough to continue")
    func testALastNameIsNotRequired() {
        let sut = makeScreen().presenter
        sut.firstName = "Ada"

        #expect(sut.canContinue)
    }

    /// Someone who signed in with Apple or Google already gave us a name; asking again reads as the
    /// app having forgotten who they are.
    @Test("The name is prefilled from the signed-in user")
    func testTheNameIsPrefilledFromTheSignedInUser() {
        let screen = makeScreen(
            user: UserModel(userId: "user-1", firstName: "Ada", lastName: "Lovelace")
        )

        screen.presenter.prefillFromCurrentUser()

        #expect(screen.presenter.firstName == "Ada")
        #expect(screen.presenter.lastName == "Lovelace")
    }

    /// The view prefills on every `onAppear`, so a provider that gave us no name must not wipe what
    /// the user has since typed.
    @Test("Prefilling keeps what the user has already typed")
    func testPrefillingKeepsWhatWasAlreadyTyped() {
        let screen = makeScreen(user: UserModel(userId: "user-1"))
        screen.presenter.firstName = "Grace"
        screen.presenter.lastName = "Hopper"

        screen.presenter.prefillFromCurrentUser()

        #expect(screen.presenter.firstName == "Grace")
        #expect(screen.presenter.lastName == "Hopper")
    }

    /// Continue is disabled without a name, but the guard is what stops anything else — a stray
    /// keyboard return, a future caller — from saving an empty profile and moving on.
    @Test("Continuing without a name saves nothing and goes nowhere")
    func testContinuingWithoutANameSavesNothing() async {
        let screen = makeScreen()
        screen.presenter.lastName = "Lovelace"

        screen.presenter.saveAndContinue()

        // The guard is synchronous today. Polling rather than asserting straight away keeps the
        // test honest if the guard ever moves inside the task that does the saving.
        let saved = await TestManagers.eventually(timeout: .milliseconds(200)) {
            !screen.interactor.savedNames.isEmpty
        }
        #expect(!saved)
        #expect(screen.router.shown.isEmpty)
    }

    /// The name the user typed has to be the name that is saved, and only then does the flow move on.
    @Test("The typed name is saved before the flow moves on")
    func testTheTypedNameIsSavedBeforeMovingOn() async {
        let screen = makeScreen()
        screen.presenter.firstName = "Ada"
        screen.presenter.lastName = "Lovelace"

        screen.presenter.saveAndContinue()
        await TestManagers.eventually { !screen.router.shown.isEmpty }

        #expect(screen.interactor.savedNames.map(\.first) == ["Ada"])
        #expect(screen.interactor.savedNames.map(\.last) == ["Lovelace"])
        #expect(screen.router.shown == ["gender"])
        #expect(screen.interactor.trackedEventNames.contains("NamePhoto_Save_Success"))
    }

    /// The screen already refuses to treat whitespace as a name, so it must not then store the
    /// whitespace around one — a saved " Ada " greets the user with a stray space forever.
    @Test("Whitespace around the name is trimmed before it is saved")
    func testWhitespaceAroundTheNameIsTrimmedBeforeSaving() async {
        let screen = makeScreen()
        screen.presenter.firstName = "  Ada "
        screen.presenter.lastName = "\nLovelace  "

        screen.presenter.saveAndContinue()
        await TestManagers.eventually { !screen.router.shown.isEmpty }

        #expect(screen.interactor.savedNames.map(\.first) == ["Ada"])
        #expect(screen.interactor.savedNames.map(\.last) == ["Lovelace"])
    }

    /// Moving on after a failed save would leave the user with a profile that never got their name
    /// and no way to notice.
    @Test("A failed save explains itself and stays put")
    func testAFailedSaveExplainsItselfAndStaysPut() async {
        let screen = makeScreen()
        screen.interactor.nameSaveError = URLError(.notConnectedToInternet)
        screen.presenter.firstName = "Ada"

        screen.presenter.saveAndContinue()
        await TestManagers.eventually { !screen.router.alertTitles.isEmpty }

        #expect(screen.router.alertTitles == ["Unable to save"])
        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.trackedEventNames.contains("NamePhoto_Save_Fail"))
    }

    /// Every other outcome of the photo picker is logged; the picker handing back nothing was the
    /// one that returned in silence, so the photo funnel counted fewer attempts than were made.
    @Test("The picker handing back nothing is recorded")
    func testThePickerHandingBackNothingIsRecorded() async {
        let screen = makeScreen()

        await screen.presenter.handlePhotoSelection()

        #expect(screen.interactor.trackedEventNames == ["NamePhoto_PhotoNotSelected"])
    }

    /// A chosen photo is uploaded before the name, so an upload that fails has to surface rather
    /// than quietly dropping the photo and carrying on as though it had worked.
    @Test("A photo that fails to upload stops the flow instead of being dropped")
    func testAFailedPhotoUploadStopsTheFlow() async {
        let screen = makeScreen()
        screen.interactor.imageUploadError = URLError(.timedOut)
        screen.presenter.firstName = "Ada"
        screen.presenter.selectedImageData = onePixelPNGData()

        screen.presenter.saveAndContinue()
        await TestManagers.eventually { !screen.router.alertTitles.isEmpty }

        #expect(screen.router.alertTitles == ["Unable to save"])
        #expect(screen.router.shown.isEmpty)
        // The name is saved after the photo, so a failed upload must not leave the profile
        // half-written either.
        #expect(screen.interactor.savedNames.isEmpty)
    }

    /// The common case: a photo was picked, so it is uploaded alongside the name.
    @Test("A chosen photo is uploaded along with the name")
    func testAChosenPhotoIsUploadedWithTheName() async {
        let screen = makeScreen()
        screen.presenter.firstName = "Ada"
        screen.presenter.selectedImageData = onePixelPNGData()

        screen.presenter.saveAndContinue()
        await TestManagers.eventually { !screen.router.shown.isEmpty }

        #expect(screen.interactor.uploadedImageCount == 1)
        #expect(screen.router.shown == ["gender"])
    }

    /// The photo is optional, so no upload should be attempted when none was picked.
    @Test("No photo means no upload is attempted")
    func testNoPhotoMeansNoUpload() async {
        let screen = makeScreen()
        screen.presenter.firstName = "Ada"

        screen.presenter.saveAndContinue()
        await TestManagers.eventually { !screen.router.shown.isEmpty }

        #expect(screen.interactor.uploadedImageCount == 0)
    }

    /// Nothing picked means nothing to load, and in particular nothing logged as though a photo
    /// *had* been chosen — `NamePhoto_PhotoNotSelected` is the opposite claim to
    /// `NamePhoto_PhotoSelected`, not a weaker version of it.
    @Test("An empty photo selection loads nothing")
    func testNoPhotoSelectionLoadsNothing() async {
        let screen = makeScreen()

        await screen.presenter.handlePhotoSelection()

        #expect(!screen.interactor.trackedEventNames.contains("NamePhoto_PhotoSelected"))
        #expect(screen.presenter.selectedImageData == nil)
    }

    /// Finding 17: the control's label and the option to remove a photo both depend on whether one
    /// is actually set, not a fixed "Add Photo" that never changed.
    @Test("A photo is reported as set once picked, and cleared once removed")
    func testHasPhotoFollowsWhatIsActuallySet() {
        let screen = makeScreen()
        #expect(!screen.presenter.hasPhoto)

        screen.presenter.selectedImageData = onePixelPNGData()
        #expect(screen.presenter.hasPhoto)

        screen.presenter.removePhoto()
        #expect(!screen.presenter.hasPhoto)
        #expect(screen.presenter.selectedImageData == nil)
        #expect(screen.presenter.selectedPhotoItem == nil)
    }
}

// MARK: - Step 2: gender

/// Two buttons feeding the sex term of the Mifflin-St Jeor equation at the end of the flow. The
/// wrong one — or a default nobody picked — changes the calorie target the user then lives by.
@MainActor
struct OnboardingGenderPresenterTests {

    private final class Interactor: SpyGlobalInteractor, GenderInteractor { func readSexFromAppleHealth() async -> Gender? { nil } }

    private final class Router: SpyOnboardingRouter, GenderRouter {
        private(set) var dateOfBirthDelegates: [DateOfBirthDelegate] = []

        func showDateOfBirthView(delegate: DateOfBirthDelegate) {
            dateOfBirthDelegates.append(delegate)
            record("dateOfBirth")
        }

        func showDevSettingsView() { record("devSettings") }
    }

    private struct Screen {
        let presenter: GenderPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: GenderPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// Nothing is preselected, because a default here is a guess the user would have to notice to
    /// correct.
    @Test("Nothing is chosen until the user chooses")
    func testNothingIsChosenToBeginWith() {
        let sut = makeScreen().presenter

        #expect(sut.selectedGender == nil)
        #expect(!sut.canSubmit)
    }

    /// Continuing with nothing chosen would carry a sex the user never picked into the BMR maths.
    @Test("Continuing with nothing chosen goes nowhere")
    func testGenderMustBeChosenBeforeContinuing() {
        let screen = makeScreen()

        screen.presenter.onContinuePressed()

        #expect(screen.router.dateOfBirthDelegates.isEmpty)
        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.trackedEventNames.isEmpty)
    }

    @Test("The chosen gender travels to the next step")
    func testTheChosenGenderTravelsToTheNextStep() {
        let screen = makeScreen()
        screen.presenter.selectedGender = .female

        #expect(screen.presenter.canSubmit)
        screen.presenter.onContinuePressed()

        #expect(screen.router.dateOfBirthDelegates.map(\.gender) == [.female])
        #expect(screen.interactor.trackedEventNames == ["GenderView_Navigate"])
    }

    /// Changing the answer before continuing has to change what is carried forward, not append to it.
    @Test("Only the last choice travels when the user changes their mind")
    func testChangingTheChoiceCarriesTheLatestOne() {
        let screen = makeScreen()
        screen.presenter.selectedGender = .female
        screen.presenter.selectedGender = .male

        screen.presenter.onContinuePressed()

        #expect(screen.router.dateOfBirthDelegates.map(\.gender) == [.male])
    }

    /// Appearing is a screen event and leaving is an ordinary one; the two go to different places
    /// in the analytics, which is easy to get backwards.
    @Test("Appearing and leaving are logged separately")
    func testAppearingAndLeavingAreBothLogged() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["GenderView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["GenderView_Disappear"])
    }
}

// MARK: - Step 3: date of birth

/// Age is one of the four Mifflin-St Jeor inputs. This screen also has to keep hold of the gender
/// picked on the step before it: the delegate chain is the only thing carrying it forward.
@MainActor
struct OnboardingDateOfBirthPresenterTests {

    private final class Interactor: SpyGlobalInteractor, DateOfBirthInteractor { func readDateOfBirthFromAppleHealth() async -> Date? { nil } }

    private final class Router: SpyOnboardingRouter, DateOfBirthRouter {
        private(set) var heightDelegates: [HeightDelegate] = []

        func showHeightView(delegate: HeightDelegate) {
            heightDelegates.append(delegate)
            record("height")
        }

        func showDevSettingsView() { record("devSettings") }
    }

    private struct Screen {
        let presenter: DateOfBirthPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: DateOfBirthPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// The picker opens on an eighteenth birthday rather than today, so tapping straight through
    /// records an adult rather than a newborn.
    @Test("The picker opens eighteen years ago rather than today")
    func testThePickerOpensOnAnAdultDate() {
        let sut = makeScreen().presenter

        let years = Calendar.current.dateComponents([.year], from: sut.dateOfBirth, to: Date()).year

        #expect(years == 18)
    }

    /// Nobody was born tomorrow. An unbounded picker let them be, and a negative age feeds straight
    /// into the expenditure estimate four steps later.
    @Test("The selectable dates stop at today")
    func testTheDateRangeExcludesTheFuture() {
        let sut = makeScreen().presenter

        #expect(sut.dateRange.upperBound <= Date())
        #expect(!sut.dateRange.contains(Date().addingTimeInterval(60 * 60 * 24)))
    }

    /// The other end has to stay far enough back that a genuinely old user is not pushed forward
    /// into a birth date that is not theirs.
    @Test("A hundred-year-old can still pick their own birth date")
    func testTheDateRangeReachesBackACentury() {
        let sut = makeScreen().presenter
        let aCenturyAgo = Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date()

        #expect(sut.dateRange.contains(aCenturyAgo))
    }

    /// Gender arrived on the delegate and the date is chosen here; both have to leave together or
    /// the expenditure screen computes for the wrong person.
    @Test("The date and the gender before it both move on")
    func testTheDateAndTheGenderBeforeItBothMoveOn() {
        let screen = makeScreen()
        screen.presenter.dateOfBirth = onboardingBirthDate

        screen.presenter.onContinuePressed(delegate: DateOfBirthDelegate(gender: .male))

        #expect(screen.router.heightDelegates.map(\.gender) == [.male])
        #expect(screen.router.heightDelegates.map(\.dateOfBirth) == [onboardingBirthDate])
    }

    /// The date travels as an instant, not as an age, so an unusually old user is carried through
    /// unchanged rather than clamped to something more typical.
    @Test("A birth date deep in the past travels unaltered")
    func testAVeryOldBirthDateTravelsUnaltered() {
        let screen = makeScreen()
        let longAgo = Calendar.current.date(from: DateComponents(year: 1926, month: 4, day: 21)) ?? Date()
        screen.presenter.dateOfBirth = longAgo

        screen.presenter.onContinuePressed(delegate: DateOfBirthDelegate(gender: .female))

        #expect(screen.router.heightDelegates.map(\.dateOfBirth) == [longAgo])
    }

    /// This step logged `GenderView_Navigate`, so in the analytics it was indistinguishable from the
    /// step before it and the drop-off between the two could not be seen.
    @Test("Continuing logs this step rather than the one before it")
    func testContinuingLogsItsOwnNavigationEvent() {
        let screen = makeScreen()

        screen.presenter.onContinuePressed(delegate: DateOfBirthDelegate(gender: .male))

        #expect(screen.interactor.trackedEventNames == ["DateOfBirthView_Navigate"])
    }
}

// MARK: - Step 4: height

/// Height is entered in either centimetres or feet and inches, and only the centimetre value is
/// carried forward — the chosen unit rides along separately so the rest of the app can show the
/// number back the way it was typed.
///
/// The conversion arithmetic between the two pickers lives in `OnboardingHeightConversionTests`.
@MainActor
struct OnboardingHeightPresenterTests {

    private final class Interactor: SpyGlobalInteractor, HeightInteractor { func readHeightCentimetersFromAppleHealth() async -> Double? { nil } }

    private final class Router: SpyOnboardingRouter, HeightRouter {
        private(set) var weightDelegates: [WeightDelegate] = []

        func showWeightView(delegate: WeightDelegate) {
            weightDelegates.append(delegate)
            record("weight")
        }

        func showDevSettingsView() { record("devSettings") }
    }

    private struct Screen {
        let presenter: HeightPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: HeightPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// Tapping straight through has to leave a plausible adult rather than a zero, since nothing
    /// downstream asks again. The default unit follows the device locale (finding 5), so only the
    /// centimetre value — which both pickers agree on — is asserted here.
    @Test("The picker starts at a plausible adult height in centimetres")
    func testTheHeightPickerStartsSomewherePlausible() {
        let sut = makeScreen().presenter

        #expect(sut.selectedCentimeters == 175)
    }

    /// A US locale expects Imperial by default; anywhere else expects Metric. Nothing under
    /// `Compound/` reads `Locale.current` at test time except this presenter, so this is the one
    /// place a locale-dependent default needs its own coverage.
    @Test("The default unit follows the device's measurement system")
    func testTheDefaultUnitFollowsTheLocale() {
        let sut = makeScreen().presenter

        let expected: UnitOfLength = Locale.current.measurementSystem == .metric ? .centimeters : .inches
        let expectedPreference: LengthUnitPreference = expected == .centimeters ? .centimeters : .inches
        #expect(sut.unit == expected)
        #expect(sut.preference == expectedPreference)
    }

    /// Whichever picker was used, centimetres is what the rest of the app stores and computes with.
    @Test("Height is handed on in centimetres with the unit the user chose")
    func testHeightLeavesInCentimetresWithTheChosenUnit() {
        let screen = makeScreen()
        screen.presenter.unit = .inches
        screen.presenter.selectedFeet = 5
        screen.presenter.selectedInches = 9
        screen.presenter.updateCentimetersFromImperial()

        screen.presenter.onContinuePressed(delegate: heightDelegate())

        #expect(screen.router.weightDelegates.map(\.lengthUnitPreference) == [.inches])
        #expect(screen.router.weightDelegates.first?.heightInCentimeters == 175)
        #expect(screen.interactor.trackedEventNames == ["HeightView_Navigate"])
    }

    /// Someone who never leaves the metric picker must be recorded as preferring centimetres, or
    /// every height in the app is shown back to them in feet.
    @Test("Staying on the metric picker carries the centimetre preference forward")
    func testTheMetricPreferenceTravels() {
        let screen = makeScreen()
        screen.presenter.selectedCentimeters = 183

        screen.presenter.onContinuePressed(delegate: heightDelegate())

        #expect(screen.router.weightDelegates.map(\.lengthUnitPreference) == [.centimeters])
        #expect(screen.router.weightDelegates.first?.heightInCentimeters == 183)
    }

    /// The earlier answers ride along on the delegate; dropping one here leaves the expenditure
    /// screen with a height but no age or sex.
    @Test("The earlier answers ride along with the height")
    func testTheEarlierAnswersRideAlongWithTheHeight() {
        let screen = makeScreen()

        screen.presenter.onContinuePressed(delegate: heightDelegate(gender: .female))

        #expect(screen.router.weightDelegates.map(\.gender) == [.female])
        #expect(screen.router.weightDelegates.map(\.dateOfBirth) == [onboardingBirthDate])
    }

    /// The two pickers offer 100–250 cm and 3–8 ft. Those ranges have to agree, or a height picked
    /// at one end of the metric wheel cannot be shown on the imperial one at all.
    @Test("Both ends of the centimetre picker land inside the feet and inches picker")
    func testTheExtremesOfOnePickerFitTheOther() {
        let sut = makeScreen().presenter

        sut.selectedCentimeters = 100
        sut.updateImperialFromCentimeters()
        #expect((3...8).contains(sut.selectedFeet))
        #expect((0...11).contains(sut.selectedInches))

        sut.selectedCentimeters = 250
        sut.updateImperialFromCentimeters()
        #expect((3...8).contains(sut.selectedFeet))
        #expect((0...11).contains(sut.selectedInches))
    }

    /// Flipping the unit toggle changes which picker is shown and what preference is stored, but it
    /// must not alter the height itself.
    @Test("Switching the unit toggle does not move the height")
    func testSwitchingTheUnitLeavesTheHeightAlone() {
        let screen = makeScreen()
        screen.presenter.selectedCentimeters = 183
        screen.presenter.updateImperialFromCentimeters()

        screen.presenter.unit = .inches
        screen.presenter.onContinuePressed(delegate: heightDelegate())

        #expect(screen.router.weightDelegates.first?.heightInCentimeters == 183)
        #expect(screen.router.weightDelegates.map(\.lengthUnitPreference) == [.inches])
    }
}

// MARK: - Step 5: weight

/// Finding 5: the weight screen used to always open on Metric regardless of what was chosen a
/// screen earlier on height, so a person who switched to Imperial once had to switch again.
@MainActor
struct OnboardingWeightPresenterTests {

    private final class Interactor: SpyGlobalInteractor, WeightInteractor { func readWeightKilogramsFromAppleHealth() async -> Double? { nil } }

    private final class Router: SpyOnboardingRouter, WeightRouter {
        private(set) var exerciseFrequencyDelegates: [ExerciseFrequencyDelegate] = []

        func showExerciseFrequencyView(delegate: ExerciseFrequencyDelegate) {
            exerciseFrequencyDelegates.append(delegate)
            record("exerciseFrequency")
        }

        func showDevSettingsView() { record("devSettings") }
    }

    private struct Screen {
        let presenter: WeightPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: WeightPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// The height step's preference for centimetres carries forward as kilograms.
    @Test("Choosing centimetres on the height step opens the weight screen on kilograms")
    func testCentimetrePreferenceOpensOnKilograms() {
        let screen = makeScreen()

        screen.presenter.onAppear(delegate: .mock)

        #expect(screen.presenter.unit == .kilograms)
    }

    /// The height step's preference for inches carries forward as pounds — the screen must not
    /// fall back to Metric just because that is the presenter's own default.
    @Test("Choosing inches on the height step opens the weight screen on pounds")
    func testInchesPreferenceOpensOnPounds() {
        let screen = makeScreen()
        let delegate = WeightDelegate(delegate: .mock, heightInCentimeters: 180, lengthUnitPreference: .inches)

        screen.presenter.onAppear(delegate: delegate)

        #expect(screen.presenter.unit == .pounds)
    }

    /// Converting kilograms to pounds and back must round, not truncate, or the displayed weight
    /// drifts every time the unit toggle is flipped.
    @Test("Converting between units rounds rather than truncates")
    func testConversionRoundsInsteadOfTruncating() {
        let screen = makeScreen()
        screen.presenter.selectedPounds = 154

        screen.presenter.updateKilogramsFromPounds()

        #expect(screen.presenter.selectedKilograms == 70)
    }
}
