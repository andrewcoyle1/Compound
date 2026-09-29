//
//  OnboardingAppleHealthFillTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

/// "Fill from Apple Health" on the date of birth, sex, height and weight steps (decision 11e), and
/// the sex step's third option (decision 8a). A fill sets the control; nothing found leaves it as
/// it was and says so.
@MainActor
struct OnboardingAppleHealthFillTests {

    private final class Interactor: SpyGlobalInteractor, GenderInteractor, DateOfBirthInteractor, HeightInteractor, WeightInteractor {
        var sex: Gender?
        var dateOfBirth: Date?
        var centimeters: Double?
        var kilograms: Double?

        func readSexFromAppleHealth() async -> Gender? { sex }
        func readDateOfBirthFromAppleHealth() async -> Date? { dateOfBirth }
        func readHeightCentimetersFromAppleHealth() async -> Double? { centimeters }
        func readWeightKilogramsFromAppleHealth() async -> Double? { kilograms }
    }

    private final class Router: SpyOnboardingRouter, GenderRouter, DateOfBirthRouter, HeightRouter, WeightRouter {
        private(set) var dateOfBirthDelegates: [DateOfBirthDelegate] = []
        func showDevSettingsView() { }
        func showDateOfBirthView(delegate: DateOfBirthDelegate) { dateOfBirthDelegates.append(delegate) }
        func showHeightView(delegate: HeightDelegate) { }
        func showWeightView(delegate: WeightDelegate) { }
        func showExerciseFrequencyView(delegate: ExerciseFrequencyDelegate) { }
    }

    // MARK: - Sex

    @Test("Prefer not to say is offered last, with a note, and is carried forward")
    func testPreferNotToSayIsOffered() {
        let router = Router()
        let sut = GenderPresenter(interactor: Interactor(), router: router)

        #expect(sut.options == [.male, .female, .preferNotToSay])
        #expect(sut.detail(for: .preferNotToSay) != nil)
        #expect(sut.detail(for: .male) == nil)

        sut.onGenderSelected(.preferNotToSay)
        sut.onContinuePressed()

        #expect(router.dateOfBirthDelegates.map(\.gender) == [.preferNotToSay])
    }

    @Test("Fill selects the sex Apple Health holds")
    func testFillSelectsTheStoredSex() async {
        let interactor = Interactor()
        interactor.sex = .female
        let sut = GenderPresenter(interactor: interactor, router: Router())

        sut.onFillFromAppleHealthPressed()

        #expect(await TestManagers.eventually { sut.healthFill == .filled })
        #expect(sut.selectedGender == .female)
        #expect(interactor.trackedEventNames == ["GenderView_FillFromHealth"])
    }

    @Test("Nothing found leaves the chosen sex alone and says so")
    func testNothingFoundLeavesTheSexAlone() async {
        let sut = GenderPresenter(interactor: Interactor(), router: Router())
        sut.selectedGender = .male

        sut.onFillFromAppleHealthPressed()

        #expect(await TestManagers.eventually { sut.healthFill == .notFound })
        #expect(sut.selectedGender == .male)
    }

    // MARK: - Date of birth

    @Test("Fill sets the stored date of birth")
    func testFillSetsTheDate() async {
        let interactor = Interactor()
        let stored = Calendar.current.date(byAdding: .year, value: -40, to: Date()) ?? Date()
        interactor.dateOfBirth = stored
        let sut = DateOfBirthPresenter(interactor: interactor, router: Router())

        sut.onFillFromAppleHealthPressed()

        #expect(await TestManagers.eventually { sut.healthFill == .filled })
        #expect(sut.dateOfBirth == stored)
    }

    /// A date the picker cannot show is treated as nothing found rather than silently clamped.
    @Test("A stored date outside the picker's range counts as nothing found")
    func testADateOutsideTheRangeIsIgnored() async {
        let interactor = Interactor()
        interactor.dateOfBirth = Date().addingTimeInterval(86_400 * 30)
        let sut = DateOfBirthPresenter(interactor: interactor, router: Router())
        let before = sut.dateOfBirth

        sut.onFillFromAppleHealthPressed()

        #expect(await TestManagers.eventually { sut.healthFill == .notFound })
        #expect(sut.dateOfBirth == before)
    }

    // MARK: - Height

    @Test("Fill sets both height wheels from the latest sample")
    func testFillSetsBothHeightWheels() async {
        let interactor = Interactor()
        interactor.centimeters = 182.4
        let sut = HeightPresenter(interactor: interactor, router: Router())

        sut.onFillFromAppleHealthPressed()

        #expect(await TestManagers.eventually { sut.healthFill == .filled })
        #expect(sut.selectedCentimeters == 182)
        // 182 cm is 71.65 in, which rounds to 6 ft 0 in.
        #expect(sut.selectedFeet == 6)
        #expect(sut.selectedInches == 0)
    }

    @Test("Nothing found leaves the height wheel as it was")
    func testNothingFoundLeavesTheHeight() async {
        let sut = HeightPresenter(interactor: Interactor(), router: Router())

        sut.onFillFromAppleHealthPressed()

        #expect(await TestManagers.eventually { sut.healthFill == .notFound })
        #expect(sut.selectedCentimeters == 175)
    }

    // MARK: - Weight

    /// Both wheels are filled, so the value stands whichever unit is showing.
    @Test("Fill sets both weight wheels from the latest sample")
    func testFillSetsBothWeightWheels() async {
        let interactor = Interactor()
        interactor.kilograms = 81.6
        let sut = WeightPresenter(interactor: interactor, router: Router())

        sut.onFillFromAppleHealthPressed()

        #expect(await TestManagers.eventually { sut.healthFill == .filled })
        #expect(sut.selectedKilograms == 82)
        #expect(sut.selectedPounds == 181)
        #expect(interactor.trackedEventNames == ["WeightView_FillFromHealth"])
    }

    @Test("Nothing found leaves the weight wheel as it was")
    func testNothingFoundLeavesTheWeight() async {
        let sut = WeightPresenter(interactor: Interactor(), router: Router())
        let before = sut.selectedKilograms

        sut.onFillFromAppleHealthPressed()

        #expect(await TestManagers.eventually { sut.healthFill == .notFound })
        #expect(sut.selectedKilograms == before)
    }
}
