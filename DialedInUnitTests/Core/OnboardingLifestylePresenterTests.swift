//
//  OnboardingLifestylePresenterTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

// Steps 6, 7 and 8 of account setup: how often the user trains, how much they move, and how fit
// their cardio is.
//
// Nothing is written to the profile on any of these screens — each one folds its answer into a
// delegate and pushes the next screen. The whole chain is only saved on the expenditure screen, so
// an answer dropped here is an answer the user is silently asked for again on the next launch.
// That makes "the delegate carries everything" the thing worth asserting, not the navigation.

/// A fixed date of birth, so age is stable between runs and is never today's date.
@MainActor
private func lifestyleBirthDate(yearsAgo: Int) -> Date {
    Calendar.current.date(byAdding: .year, value: -yearsAgo, to: Date()) ?? Date()
}

// MARK: - Step 6: exercise frequency

/// How often the user trains. It scales the whole expenditure estimate by up to a fifth, so the
/// answer has to arrive intact and it has to be the one they picked.
@MainActor
struct ExerciseFrequencyPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ExerciseFrequencyInteractor { }

    private final class Router: ExerciseFrequencyRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var activityDelegates: [ActivityDelegate] = []

        func showActivityView(delegate: ActivityDelegate) { activityDelegates.append(delegate) }

        // Declared unguarded: the app declares it under `#if DEV || MOCK`, but the test target is
        // built without either flag, so a guarded copy here would not compile.
        func showDevSettingsView() { }
    }

    private func makeDelegate() -> ExerciseFrequencyDelegate {
        ExerciseFrequencyDelegate(
            delegate: WeightDelegate(
                delegate: HeightDelegate(
                    delegate: DateOfBirthDelegate(gender: .male),
                    dateOfBirth: lifestyleBirthDate(yearsAgo: 30)
                ),
                heightInCentimeters: 180,
                lengthUnitPreference: .centimeters
            ),
            weightInKilograms: 80,
            weightUnitPreference: .kilograms
        )
    }

    @Test("Continue does nothing until a training frequency has been picked")
    func testATrainingFrequencyMustBePickedToMoveOn() {
        let router = Router()
        let sut = ExerciseFrequencyPresenter(interactor: Interactor(), router: router)

        #expect(sut.canSubmit == false)
        sut.onContinuePressed(delegate: makeDelegate())

        // An unanswered question silently defaulting to "never" would understate every calorie
        // target that follows, so nothing may be carried forward.
        #expect(router.activityDelegates.isEmpty)
    }

    @Test("The picked frequency is the one carried to the next screen")
    func testThePickedFrequencyIsCarriedForward() {
        let router = Router()
        let sut = ExerciseFrequencyPresenter(interactor: Interactor(), router: router)

        sut.selectedFrequency = .fiveToSix
        #expect(sut.canSubmit)
        sut.onContinuePressed(delegate: makeDelegate())

        #expect(router.activityDelegates.map(\.exerciseFrequency) == [.fiveToSix])
    }

    @Test("Everything gathered before this step travels on with the frequency")
    func testTheProfileSoFarTravelsWithTheFrequency() {
        let router = Router()
        let sut = ExerciseFrequencyPresenter(interactor: Interactor(), router: router)
        sut.selectedFrequency = .daily

        sut.onContinuePressed(delegate: makeDelegate())

        let arrived = router.activityDelegates.first
        #expect(arrived?.gender == .male)
        #expect(arrived?.heightInCentimetres == 180)
        #expect(arrived?.weightInKilograms == 80)
        #expect(arrived?.lengthUnitPreference == .centimeters)
        #expect(arrived?.weightUnitPreference == .kilograms)
    }

    @Test("Moving on is tracked")
    func testMovingOnIsTracked() {
        let interactor = Interactor()
        let sut = ExerciseFrequencyPresenter(interactor: interactor, router: Router())
        sut.selectedFrequency = .oneToTwo

        sut.onContinuePressed(delegate: makeDelegate())

        #expect(interactor.trackedEventNames == ["OnboardingExerciseFreqView_Navigate"])
    }
}

// MARK: - Step 7: daily activity

/// The bigger of the two multipliers in the expenditure formula — sedentary to very active is a
/// 58% swing on the whole basal rate.
@MainActor
struct ActivityPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ActivityInteractor { }

    private final class Router: ActivityRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var expenditureDelegates: [ExpenditureDelegate] = []

        func showExpenditureView(delegate: ExpenditureDelegate) { expenditureDelegates.append(delegate) }
        func showDevSettingsView() { }
    }

    private func makeDelegate() -> ActivityDelegate {
        ActivityDelegate(
            delegate: ExerciseFrequencyDelegate(
                delegate: WeightDelegate(
                    delegate: HeightDelegate(
                        delegate: DateOfBirthDelegate(gender: .female),
                        dateOfBirth: lifestyleBirthDate(yearsAgo: 40)
                    ),
                    heightInCentimeters: 165,
                    lengthUnitPreference: .centimeters
                ),
                weightInKilograms: 62,
                weightUnitPreference: .pounds
            ),
            exerciseFrequency: .threeToFour
        )
    }

    @Test("Continue does nothing until an activity level has been picked")
    func testAnActivityLevelMustBePickedToMoveOn() {
        let router = Router()
        let sut = ActivityPresenter(interactor: Interactor(), router: router)

        #expect(sut.canSubmit == false)
        sut.onContinuePressed(delegate: makeDelegate())

        #expect(router.expenditureDelegates.isEmpty)
    }

    @Test("The picked activity level is the one carried to the next screen")
    func testThePickedActivityLevelIsCarriedForward() {
        let router = Router()
        let sut = ActivityPresenter(interactor: Interactor(), router: router)

        sut.selectedActivityLevel = .active
        #expect(sut.canSubmit)
        sut.onContinuePressed(delegate: makeDelegate())

        #expect(router.expenditureDelegates.map(\.activityLevel) == [.active])
    }

    @Test("The unit preferences survive the activity step")
    func testTheUnitPreferencesSurviveTheActivityStep() {
        let router = Router()
        let sut = ActivityPresenter(interactor: Interactor(), router: router)
        sut.selectedActivityLevel = .light

        sut.onContinuePressed(delegate: makeDelegate())

        // The weight unit is a display preference set three screens ago. Losing it here would show
        // a pounds user their goal in kilograms for the rest of the app.
        #expect(router.expenditureDelegates.map(\.weightUnitPreference) == [.pounds])
        #expect(router.expenditureDelegates.map(\.exerciseFrequency) == [.threeToFour])
    }

    // The cardio fitness step used to sit between this one and the expenditure screen; it left
    // onboarding (decision 8c), so these two checks moved here from its suite.

    @Test("Every answer since the gender step arrives at the expenditure screen together")
    func testEveryAnswerSinceTheGenderStepArrivesTogether() {
        let router = Router()
        let sut = ActivityPresenter(interactor: Interactor(), router: router)
        sut.selectedActivityLevel = .moderate

        sut.onContinuePressed(delegate: makeDelegate())

        // This delegate is the whole of what the expenditure screen writes to the profile. Anything
        // missing here is a field onboarding will ask for again.
        let arrived = router.expenditureDelegates.first
        #expect(arrived?.gender == .female)
        #expect(arrived?.heightInCentimetres == 165)
        #expect(arrived?.lengthUnitPreference == .centimeters)
        #expect(arrived?.weightInKilograms == 62)
        #expect(arrived?.weightUnitPreference == .pounds)
        #expect(arrived?.exerciseFrequency == .threeToFour)
        #expect(arrived?.activityLevel == .moderate)
    }

    @Test("The date of birth is passed through unchanged rather than re-derived")
    func testTheDateOfBirthIsPassedThroughUnchanged() {
        let router = Router()
        let sut = ActivityPresenter(interactor: Interactor(), router: router)
        sut.selectedActivityLevel = .light

        // Captured once: the delegate builds its date from `Date()`, so two calls never match.
        let delegate = makeDelegate()
        sut.onContinuePressed(delegate: delegate)

        #expect(router.expenditureDelegates.first?.dateOfBirth == delegate.dateOfBirth)
    }

    @Test("Moving on is tracked")
    func testMovingOnIsTracked() {
        let interactor = Interactor()
        let sut = ActivityPresenter(interactor: interactor, router: Router())
        sut.selectedActivityLevel = .moderate

        sut.onContinuePressed(delegate: makeDelegate())

        #expect(interactor.trackedEventNames == ["ActivityLevel_Navigate"])
    }
}
