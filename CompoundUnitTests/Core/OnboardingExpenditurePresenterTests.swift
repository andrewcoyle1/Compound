//
//  OnboardingExpenditurePresenterTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

// Step 9: the screen that turns everything collected since the gender question into a number of
// calories, and then writes the whole profile in one go.
//
// Two things make this screen worth testing hard. The arithmetic is the base every calorie target
// in the app is later derived from, so an error here is invisible and permanent. And the figures
// are read straight from the view body — `bmrInt`, `tdeeInt` and `breakdownItems` are all called
// while drawing — so a value that is not a number does not return nonsense, it traps.

/// A fixed date of birth, so age is stable between runs and is never today's date.
@MainActor
/// A birth date the given number of whole years ago, anchored to the start of today.
///
/// It has to be relative to now, because the presenter measures age against `Date()` itself.
/// Subtracting from `Date()` directly lands the birth date exactly N years before this instant,
/// with no margin at all: any calendar irregularity in the intervening years leaves it a moment
/// short and the age comes out one lower, which fails an exact-arithmetic assertion at random.
///
/// Anchoring to the start of today puts the birthday hours in the past rather than exactly now.
/// It must be the start of the day and not some later hour — an anchor ahead of the current time
/// would mean the birthday has not been reached yet today, which lowers the age by one for
/// every test run before it.
private func expenditureBirthDate(yearsAgo: Int) -> Date {
    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: Date())
    return calendar.date(byAdding: .year, value: -yearsAgo, to: startOfToday) ?? startOfToday
}

/// The delegate the expenditure screen receives, built field by field rather than by walking the
/// chain, so a test can vary one input at a time.
@MainActor
private func expenditureDelegate(
    gender: Gender = .male,
    dateOfBirth: Date? = nil,
    heightCm: Double = 180,
    lengthUnit: LengthUnitPreference = .centimeters,
    weightKg: Double = 80,
    weightUnit: WeightUnitPreference = .kilograms,
    exerciseFrequency: ExerciseFrequency = .never,
    activityLevel: ActivityLevel = .sedentary
) -> ExpenditureDelegate {
    let height = HeightDelegate(
        delegate: DateOfBirthDelegate(gender: gender),
        dateOfBirth: dateOfBirth ?? expenditureBirthDate(yearsAgo: 30)
    )
    let weight = WeightDelegate(
        delegate: height,
        heightInCentimeters: heightCm,
        lengthUnitPreference: lengthUnit
    )
    let frequency = ExerciseFrequencyDelegate(
        delegate: weight,
        weightInKilograms: weightKg,
        weightUnitPreference: weightUnit
    )
    let activity = ActivityDelegate(delegate: frequency, exerciseFrequency: exerciseFrequency)
    return ExpenditureDelegate(delegate: activity, activityLevel: activityLevel)
}

@MainActor
private func expenditureContext(
    from delegate: ExpenditureDelegate
) -> ExpenditurePresenter.ExpenditureContext {
    ExpenditurePresenter.ExpenditureContext(
        weight: delegate.weightInKilograms,
        height: delegate.heightInCentimetres,
        dateOfBirth: delegate.dateOfBirth,
        gender: delegate.gender,
        activityLevel: delegate.activityLevel
    )
}

@MainActor
private final class ExpenditureSpyInteractor: SpyGlobalInteractor, ExpenditureInteractor {
    var currentUser: UserModel?
    var shouldThrow = false
    private(set) var savedInputs: [[String: any DMCodableSendable]] = []

    func saveUserCompleteAccountSetup(input: [String: any DMCodableSendable]) async throws {
        if shouldThrow { throw URLError(.notConnectedToInternet) }
        savedInputs.append(input)
    }

    func estimateTDEE(user: UserModel?) -> Double { 0 }
}

/// The onward destination is an onboarding step the shared spy already records, so this only
/// adds the dev hook. The alert methods stay on `SpyOnboardingRouter`, which is the class that
/// declares the `GlobalRouter` conformance and therefore owns their witnesses.
@MainActor
private final class ExpenditureSpyRouter: SpyOnboardingRouter, ExpenditureRouter {
    func showDevSettingsView() { record("devSettings") }
}

@MainActor
private struct ExpenditureScreen {
    let sut: ExpenditurePresenter
    let interactor: ExpenditureSpyInteractor
    let router: ExpenditureSpyRouter
}

@MainActor
private func makeExpenditureScreen() -> ExpenditureScreen {
    let interactor = ExpenditureSpyInteractor()
    let router = ExpenditureSpyRouter()
    return ExpenditureScreen(
        sut: ExpenditurePresenter(interactor: interactor, router: router),
        interactor: interactor,
        router: router
    )
}

// MARK: - The arithmetic

/// TDEE = Mifflin-St Jeor BMR x the PAL for the activity answer, the same `FormulaExpenditure` the
/// manager runs. The expected numbers below are worked by hand from that formula, because a
/// multiplier applied twice would still produce something that looks entirely reasonable on screen.
@MainActor
struct ExpenditurePresenterArithmeticTests {

    @Test("BMR matches Mifflin-St Jeor for a man")
    func testBMRMatchesMifflinStJeorForAMan() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        // 10x80 + 6.25x180 - 5x30 + 5 = 800 + 1125 - 150 + 5
        let bmr = sut.bmrInt(weight: 80, height: 180, dateOfBirth: expenditureBirthDate(yearsAgo: 30), gender: .male)

        #expect(bmr == 1780)
    }

    @Test("BMR matches Mifflin-St Jeor for a woman")
    func testBMRMatchesMifflinStJeorForAWoman() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        // The same body with the female coefficient: 800 + 1125 - 150 - 161. The 166 kcal gap is
        // the whole of the sex adjustment, so a coefficient applied with the wrong sign would be a
        // 332 kcal error in the opposite direction.
        let bmr = sut.bmrInt(weight: 80, height: 180, dateOfBirth: expenditureBirthDate(yearsAgo: 30), gender: .female)

        #expect(bmr == 1614)
    }

    /// Decision 8a: "Prefer not to say" takes the midpoint of +5 and -161.
    @Test("BMR uses the midpoint coefficient for prefer not to say")
    func testBMRUsesTheMidpointForPreferNotToSay() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        // 800 + 1125 - 150 - 78
        let bmr = sut.bmrInt(weight: 80, height: 180, dateOfBirth: expenditureBirthDate(yearsAgo: 30), gender: .preferNotToSay)

        #expect(bmr == 1697)
    }

    @Test("Age lowers BMR by five calories a year")
    func testAgeLowersBMRByFiveCaloriesAYear() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        let young = sut.bmrInt(weight: 80, height: 180, dateOfBirth: expenditureBirthDate(yearsAgo: 30), gender: .male)
        let old = sut.bmrInt(weight: 80, height: 180, dateOfBirth: expenditureBirthDate(yearsAgo: 60), gender: .male)

        #expect(young - old == 150)
    }

    @Test("The activity multipliers sit inside the FAO/WHO/UNU bands")
    func testTheActivityMultipliersAreThePublishedOnes() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        // A single one mistyped moves one group of users' targets by hundreds of calories while
        // everyone else's stay correct, which is why they are pinned one by one. Sedentary starts
        // at 1.4, the bottom of "sedentary or light" (1.40–1.69), not the 1.2 of bed rest.
        #expect(sut.baseActivityMultiplier(activityLevel: .sedentary) == 1.4)
        #expect(sut.baseActivityMultiplier(activityLevel: .light) == 1.55)
        #expect(sut.baseActivityMultiplier(activityLevel: .moderate) == 1.7)
        #expect(sut.baseActivityMultiplier(activityLevel: .active) == 1.85)
        #expect(sut.baseActivityMultiplier(activityLevel: .veryActive) == 2.0)
    }

    @Test("TDEE is BMR times the activity multiplier")
    func testTDEEIsBMRTimesTheActivityMultiplier() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        // 1780 x 1.4. An activity multiplier applied to an already-multiplied figure would show up
        // here as a number a thousand calories too high.
        let tdee = sut.tdeeInt(context: expenditureContext(from: expenditureDelegate()))

        #expect(tdee == 2492)
    }

    @Test("An active answer is its own PAL")
    func testAnActiveAnswerIsItsOwnPAL() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut
        let delegate = expenditureDelegate(exerciseFrequency: .daily, activityLevel: .active)

        // 1780 x 1.85 = 3293.
        #expect(sut.tdeeInt(context: expenditureContext(from: delegate)) == 3293)
    }

    /// Training frequency no longer adds to the PAL: the activity answers include exercise, and
    /// an extra term on top counted it twice (Pontzer 2016).
    @Test("How often someone trains does not change the estimate")
    func testExerciseFrequencyDoesNotChangeTheEstimate() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        let never = sut.tdeeInt(context: expenditureContext(from: expenditureDelegate(exerciseFrequency: .never)))
        let daily = sut.tdeeInt(context: expenditureContext(from: expenditureDelegate(exerciseFrequency: .daily)))

        #expect(daily == never)
    }

    /// The onboarding figure is the manager's own formula, so the number shown here is the number
    /// the plan is later built on.
    @Test("The screen's estimate is the manager's estimate")
    func testTheScreensEstimateIsTheManagersEstimate() {
        let screen = makeExpenditureScreen()
        let delegate = expenditureDelegate(activityLevel: .light)
        let user = UserModel(
            userId: "user-1",
            submittedDateOfBirth: delegate.dateOfBirth,
            submittedGender: delegate.gender,
            submittedHeightCentimeters: delegate.heightInCentimetres,
            submittedWeightKilograms: delegate.weightInKilograms,
            submittedDailyActivityLevel: delegate.activityLevel
        )

        let managerFigure = Int(TestManagers.nutritionManager().estimateTDEE(user: user).rounded())

        #expect(screen.sut.tdeeInt(context: expenditureContext(from: delegate)) == managerFigure)
    }
}

// MARK: - Inputs that should not have got this far

/// Everything here arrives from a bounded picker in practice. It is tested anyway because these
/// four functions are called from the view body, so a value the arithmetic cannot survive is not a
/// wrong number on screen — it is a crash while drawing.
@MainActor
struct ExpenditurePresenterDegenerateInputTests {

    @Test("A missing weight is floored rather than believed")
    func testAMissingWeightIsFloored() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        // Zero would give a BMR of 325 and a calorie target nobody could live on. The 30 kg floor
        // holds it at 300 + 1125 - 150 + 5.
        let zero = sut.bmrInt(weight: 0, height: 180, dateOfBirth: expenditureBirthDate(yearsAgo: 30), gender: .male)
        let floored = sut.bmrInt(weight: 30, height: 180, dateOfBirth: expenditureBirthDate(yearsAgo: 30), gender: .male)

        #expect(zero == 1280)
        #expect(zero == floored)
    }

    @Test("An implausible height is floored rather than believed")
    func testAnImplausibleHeightIsFloored() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        // 800 + 6.25x100 - 150 + 5, floored at the height wheel's own 100 cm minimum (finding 9),
        // rather than the 530 a literal zero would give.
        let zero = sut.bmrInt(weight: 80, height: 0, dateOfBirth: expenditureBirthDate(yearsAgo: 30), gender: .male)

        #expect(zero == 1280)
    }

    @Test("An age below fourteen is treated as fourteen")
    func testAnAgeBelowFourteenIsTreatedAsFourteen() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        // A date of birth of today, or a profile with no date that fell back to now, must not earn
        // a thirty-year age credit.
        let newborn = sut.bmrInt(weight: 80, height: 180, dateOfBirth: Date(), gender: .male)
        let teenager = sut.bmrInt(weight: 80, height: 180, dateOfBirth: expenditureBirthDate(yearsAgo: 14), gender: .male)

        #expect(newborn == teenager)
        #expect(newborn == 1860)
    }

    @Test("A date of birth in the distant past cannot drive BMR negative")
    func testADistantPastBirthdayCannotDriveBMRNegative() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        // At 5 kcal a year, an unclamped two-thousand-year age would put BMR ten thousand calories
        // below zero and every derived target with it.
        let ancient = sut.bmrInt(weight: 80, height: 180, dateOfBirth: .distantPast, gender: .male)

        #expect(ancient > 0)
        // 800 + 1125 - 5x120 + 5, the 120-year ceiling.
        #expect(ancient == 1330)
    }

    @Test("A weight that is not a number does not reach the Int conversion")
    func testANaNWeightIsTreatedAsMissing() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        // `max(_:_:)` does not filter NaN out, it propagates it — so the kilogram floor alone does
        // not stop a NaN arriving at `Int(_:)`, which traps.
        let nan = sut.bmrInt(weight: .nan, height: 180, dateOfBirth: expenditureBirthDate(yearsAgo: 30), gender: .male)
        let floored = sut.bmrInt(weight: 30, height: 180, dateOfBirth: expenditureBirthDate(yearsAgo: 30), gender: .male)

        #expect(nan == floored)
    }

    @Test("An infinite height is treated as missing rather than converted")
    func testAnInfiniteHeightIsTreatedAsMissing() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        // Infinity is not a height anyone has, so it falls to the same floor a zero does rather
        // than to the ceiling — and either way it never reaches `Int(_:)`, which would trap on it.
        let infinite = sut.bmrInt(weight: 80, height: .infinity, dateOfBirth: expenditureBirthDate(yearsAgo: 30), gender: .male)
        let zero = sut.bmrInt(weight: 80, height: 0, dateOfBirth: expenditureBirthDate(yearsAgo: 30), gender: .male)

        #expect(infinite == zero)
        // 655 + 6.25 x 100: the floor is the 100 cm the height wheel starts at, where it was 120.
        #expect(infinite == 1280)
    }

    @Test("An absurd weight is capped rather than converted")
    func testAnAbsurdWeightIsCapped() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        // 10x500 + 1125 - 150 + 5, the 500 kg ceiling. Without one, a value near `Double.greatest`
        // overflows `Int` and traps.
        let absurd = sut.bmrInt(weight: 1e300, height: 180, dateOfBirth: expenditureBirthDate(yearsAgo: 30), gender: .male)

        #expect(absurd == 5980)
    }

    @Test("TDEE stays finite and sane when every input is degenerate")
    func testTDEEStaysFiniteWhenEveryInputIsDegenerate() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut
        let delegate = expenditureDelegate(dateOfBirth: .distantFuture, heightCm: .nan, weightKg: .infinity)

        let tdee = sut.tdeeInt(context: expenditureContext(from: delegate))

        #expect(tdee >= 1000)
        #expect(tdee < 100_000)
    }

    @Test("The breakdown stays finite and still sums to the total when inputs are degenerate")
    func testTheBreakdownStaysFiniteWhenInputsAreDegenerate() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut
        let delegate = expenditureDelegate(heightCm: .nan, weightKg: .nan, exerciseFrequency: .daily, activityLevel: .veryActive)
        sut.estimateExpenditure(delegate: delegate)

        let items = sut.breakdownItems(context: expenditureContext(from: delegate))

        #expect(items.allSatisfy { $0.calories >= 0 })
        #expect(items.map(\.calories).reduce(0, +) == sut.totalExpenditureKcal)
    }

    @Test("TDEE never drops below a thousand calories")
    func testTDEENeverDropsBelowAThousandCalories() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut
        // 30 kg, 100 cm (the height wheel's own floor — finding 9), 100 years old, female,
        // sedentary: BMR is 300 + 625 - 500 - 161 = 264, and 264 x 1.4 is 370 — a figure that
        // would read as a starvation target.
        let delegate = expenditureDelegate(
            gender: .female,
            dateOfBirth: expenditureBirthDate(yearsAgo: 100),
            heightCm: 0,
            weightKg: 0
        )

        #expect(sut.tdeeInt(context: expenditureContext(from: delegate)) == 1000)
    }
}

// MARK: - The breakdown shown underneath

@MainActor
struct ExpenditurePresenterBreakdownTests {

    @Test("The three bars sum to the total shown above them")
    func testTheBreakdownSumsToTheTotalShown() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut
        let delegate = expenditureDelegate(exerciseFrequency: .threeToFour, activityLevel: .moderate)
        sut.estimateExpenditure(delegate: delegate)

        let items = sut.breakdownItems(context: expenditureContext(from: delegate))

        // The bars are the screen's explanation of the number. If they do not add up to it, the
        // screen contradicts itself in plain sight.
        #expect(items.count == 3)
        #expect(items.map(\.calories).reduce(0, +) == sut.totalExpenditureKcal)
    }

    @Test("Digestion is a tenth of the total and activity is the rest above resting")
    func testDigestionIsATenthOfTheTotal() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut
        let delegate = expenditureDelegate(exerciseFrequency: .oneToTwo, activityLevel: .moderate)
        sut.estimateExpenditure(delegate: delegate)

        let items = sut.breakdownItems(context: expenditureContext(from: delegate))

        // BMR 1780; total 1780 x 1.7 = 3026; digestion 10% of that, 303 (Westerterp 2004);
        // activity the 943 left. It used to be a rounding remainder of about zero.
        #expect(sut.totalExpenditureKcal == 3026)
        #expect(items[0].calories == 1780)
        #expect(items[1].calories == 943)
        #expect(items[2].calories == 303)
    }

    @Test("Bar progress is zero before the estimate has run")
    func testProgressIsZeroBeforeTheEstimateHasRun() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut
        let item = ExpenditurePresenter.Breakdown(name: "Basal Metabolic Rate", calories: 1780, color: .blue)

        // `progress(for:)` divides by the total, which is zero until then — a bare division would
        // make every bar NaN.
        #expect(sut.progress(for: item) == 0)
    }

    @Test("Bar progress is the share of the total once it has")
    func testProgressIsTheShareOfTheTotal() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut
        sut.estimateExpenditure(delegate: expenditureDelegate())
        let item = ExpenditurePresenter.Breakdown(name: "Basal Metabolic Rate", calories: 1246, color: .blue)

        // 1246 of 2492.
        #expect(sut.progress(for: item) == 0.5)
    }
}

// MARK: - Estimating and saving

@MainActor
struct ExpenditurePresenterSaveTests {

    @Test("Continue unlocks only once the estimate exists")
    func testContinueUnlocksOnlyOnceTheEstimateExists() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        // Nobody should be able to save a profile before the number they are agreeing to has been
        // worked out.
        #expect(sut.canContinue == false)
        #expect(sut.totalExpenditureKcal == 0)

        sut.estimateExpenditure(delegate: expenditureDelegate())

        #expect(sut.canContinue)
        #expect(sut.totalExpenditureKcal == 2492)
    }

    @Test("Pressing Continue before the estimate has run saves nothing and goes nowhere")
    func testContinueBeforeTheEstimateDoesNothing() async {
        let screen = makeExpenditureScreen()
        let sut = screen.sut
        let interactor = screen.interactor
        let router = screen.router

        sut.onContinuePressed(delegate: expenditureDelegate())
        // Short: this waits for something that must never happen, so it only needs long enough for
        // a save task to have been started had the guard let one through.
        await TestManagers.eventually(timeout: .milliseconds(300)) { !interactor.savedInputs.isEmpty }

        #expect(interactor.savedInputs.isEmpty)
        #expect(router.shown.isEmpty)
    }

    @Test("Re-estimating updates the number without replaying the count-up animation")
    func testReEstimatingUpdatesTheNumber() {
        let screen = makeExpenditureScreen()
        let sut = screen.sut

        sut.estimateExpenditure(delegate: expenditureDelegate())
        #expect(sut.hasAnimated)

        sut.estimateExpenditure(delegate: expenditureDelegate(activityLevel: .veryActive))

        // 1780 x 2.0. A user who comes back to the screen must not be shown a stale figure.
        #expect(sut.totalExpenditureKcal == 3560)
    }

    @Test("The whole profile is saved in one write")
    func testTheWholeProfileIsSavedInOneWrite() async {
        let screen = makeExpenditureScreen()
        let sut = screen.sut
        let interactor = screen.interactor
        // Captured once: the delegate's date is built from `Date()`, so two reads never match.
        let delegate = expenditureDelegate(
            gender: .female,
            dateOfBirth: expenditureBirthDate(yearsAgo: 41),
            heightCm: 165,
            lengthUnit: .inches,
            weightKg: 62.5,
            weightUnit: .pounds,
            exerciseFrequency: .fiveToSix,
            activityLevel: .light
        )
        sut.estimateExpenditure(delegate: delegate)

        sut.onContinuePressed(delegate: delegate)
        await TestManagers.eventually { !interactor.savedInputs.isEmpty }

        // Whatever is missing from this dictionary is a field onboarding asks for again next launch.
        let saved = interactor.savedInputs.first
        #expect(saved?["submitted_gender"] as? String == "female")
        #expect(saved?["submitted_date_of_birth"] as? Date == delegate.dateOfBirth)
        #expect(saved?["submitted_height_centimeters"] as? Double == 165)
        #expect(saved?["submitted_length_unit_preference"] as? String == "inches")
        #expect(saved?["submitted_weight_kilograms"] as? Double == 62.5)
        #expect(saved?["submitted_weight_unit_preference"] as? String == "pounds")
        #expect(saved?["submitted_daily_activity_level"] as? String == "light")
        #expect(saved?["submitted_exercise_frequency"] as? String == "5-6")
        // Cardio fitness is no longer asked (decision 8c), so it is not written, and a profile
        // that already holds one keeps it.
        #expect(saved?["submitted_cardio_fitness_level"] == nil)
    }

    @Test("Saving goes straight to the disclaimer")
    func testSavingGoesStraightToTheDisclaimer() async {
        let screen = makeExpenditureScreen()
        let sut = screen.sut
        let router = screen.router
        sut.estimateExpenditure(delegate: expenditureDelegate())

        sut.onContinuePressed(delegate: expenditureDelegate())
        await TestManagers.eventually { !router.shown.isEmpty }

        // Onboarding no longer asks for notifications or Apple Health. Each is requested where
        // it is first used, so nothing stands between the profile and the disclaimer.
        #expect(router.shown == ["healthDisclaimer"])
    }

    @Test("A failed profile save is reported and goes nowhere")
    func testAFailedProfileSaveGoesNowhere() async {
        let screen = makeExpenditureScreen()
        let sut = screen.sut
        let interactor = screen.interactor
        let router = screen.router
        interactor.shouldThrow = true
        sut.estimateExpenditure(delegate: expenditureDelegate())

        sut.onContinuePressed(delegate: expenditureDelegate())
        await TestManagers.eventually { !router.alertTitles.isEmpty }

        // The screens after this one assume a profile that would not be there.
        #expect(router.alertTitles == ["Unable to Save Profile"])
        #expect(router.shown.isEmpty)
        #expect(interactor.trackedEventNames.contains("Expenditure_SaveProfile_Fail"))
    }

    @Test("The user can press Continue again after a failed save")
    func testTheUserCanRetryAfterAFailedSave() async {
        let screen = makeExpenditureScreen()
        let sut = screen.sut
        let interactor = screen.interactor
        let router = screen.router
        interactor.shouldThrow = true
        sut.estimateExpenditure(delegate: expenditureDelegate())
        sut.onContinuePressed(delegate: expenditureDelegate())
        await TestManagers.eventually { !router.alertTitles.isEmpty }

        interactor.shouldThrow = false
        sut.onContinuePressed(delegate: expenditureDelegate())
        await TestManagers.eventually { !router.shown.isEmpty }

        // A failure must not latch: `canContinue` stays set so the retry can get through.
        #expect(interactor.savedInputs.count == 1)
        #expect(router.shown == ["healthDisclaimer"])
    }
}
