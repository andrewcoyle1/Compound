//
//  OnboardingHeightConversionTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The height step lets the user switch between centimetres and feet/inches, converting whichever
/// pickers they were not touching. Truncating those conversions lost most of a unit in each
/// direction, so a value could not survive a round trip through the toggle.
@MainActor
struct OnboardingHeightConversionTests {

    private final class Interactor: HeightInteractor {
        private(set) var trackedEventNames: [String] = []
        func trackEvent(event: LoggableEvent) { trackedEventNames.append(event.eventName) }
        func readHeightCentimetersFromAppleHealth() async -> Double? { nil }
    }

    private final class Router: HeightRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var weightDelegates: [WeightDelegate] = []
        func showWeightView(delegate: WeightDelegate) { weightDelegates.append(delegate) }
        func showDevSettingsView() { }
    }

    private func presenter() -> HeightPresenter {
        HeightPresenter(interactor: Interactor(), router: Router())
    }

    @Test("Six feet is 183 cm, not the 182 that truncating produced")
    func testWholeFeetConvertToTheNearestCentimetre() {
        let sut = presenter()
        sut.selectedFeet = 6
        sut.selectedInches = 0
        sut.updateCentimetersFromImperial()

        // 72 in × 2.54 = 182.88 cm.
        #expect(sut.selectedCentimeters == 183)
    }

    @Test("175 cm is 5 ft 9 in, not the 5 ft 8 in that truncating produced")
    func testCentimetresConvertToTheNearestInch() {
        let sut = presenter()
        sut.selectedCentimeters = 175
        sut.updateImperialFromCentimeters()

        // 175 / 2.54 = 68.9 in, which is 5 ft 8.9 in.
        #expect(sut.selectedFeet == 5)
        #expect(sut.selectedInches == 9)
    }

    @Test("Rounding up to twelve inches carries into the next foot rather than reading 5 ft 12 in")
    func testARoundedTotalCarriesIntoTheNextFoot() {
        let sut = presenter()
        sut.selectedCentimeters = 183
        sut.updateImperialFromCentimeters()

        // 183 / 2.54 = 72.05 in — exactly 6 ft once rounded.
        #expect(sut.selectedFeet == 6)
        #expect(sut.selectedInches == 0)
    }

    @Test("A height entered in feet survives a trip through centimetres and back")
    func testAnImperialHeightSurvivesARoundTrip() {
        let sut = presenter()
        sut.selectedFeet = 5
        sut.selectedInches = 11
        sut.updateCentimetersFromImperial()
        sut.updateImperialFromCentimeters()

        #expect(sut.selectedFeet == 5)
        #expect(sut.selectedInches == 11)
    }

    @Test("The height handed to the next screen agrees with the pickers the user sees")
    func testTheReportedImperialHeightMatchesThePickers() {
        let sut = presenter()
        sut.unit = .inches
        sut.selectedCentimeters = 175
        sut.updateImperialFromCentimeters()

        // `height` in imperial is feet plus inches as a fraction of a foot. Reading 5 ft 9 in from
        // the pickers while reporting 5 ft 8 in was the inconsistency the shared rounded total
        // removes.
        #expect(sut.height == 5.0 + 9.0 / 12.0)
    }
}
