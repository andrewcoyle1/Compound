//
//  UnitConversionTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// Weight, length and distance conversion.
///
/// Worth pinning because the app stores one unit and shows another: weights in kilograms,
/// circumferences in centimetres, distances in metres. Every screen that shows a preference unit
/// goes through here, and a wrong factor is the kind of bug that looks plausible on screen — a
/// user who lifts 100 kg seeing 100 lbs is not obviously wrong until they compare.
@MainActor
struct UnitConversionTests {

    private func isClose(_ lhs: Double, _ rhs: Double, within tolerance: Double = 0.0001) -> Bool {
        abs(lhs - rhs) < tolerance
    }

    // MARK: - Weight

    @Test("Test Kilograms To Pounds")
    func testKilogramsToPounds() {
        #expect(isClose(UnitConversion.kgToLbs(1), 2.20462))
        #expect(isClose(UnitConversion.kgToLbs(100), 220.462))
        #expect(UnitConversion.kgToLbs(0) == 0)
    }

    @Test("Test Pounds To Kilograms")
    func testPoundsToKilograms() {
        #expect(isClose(UnitConversion.lbsToKg(2.20462), 1))
        #expect(isClose(UnitConversion.lbsToKg(220.462), 100))
        #expect(UnitConversion.lbsToKg(0) == 0)
    }

    /// The round trip is what protects stored data: a weight entered in pounds is converted to
    /// kilograms to store and back to pounds to show.
    @Test("Test Weight Round Trips Through Kilograms")
    func testWeightRoundTripsThroughKilograms() {
        for pounds in [1.0, 45.0, 135.0, 225.0, 315.0] {
            let stored = UnitConversion.lbsToKg(pounds)
            #expect(isClose(UnitConversion.kgToLbs(stored), pounds, within: 0.0001))
        }
    }

    @Test("Test Converting Weight To An Exercise Unit")
    func testConvertingWeightToAnExerciseUnit() {
        #expect(UnitConversion.convertWeight(100, to: ExerciseWeightUnit.kilograms) == 100)
        #expect(isClose(UnitConversion.convertWeight(100, to: ExerciseWeightUnit.pounds), 220.462))
    }

    @Test("Test Converting Weight Back To Kilograms")
    func testConvertingWeightBackToKilograms() {
        #expect(UnitConversion.convertWeightToKg(100, from: ExerciseWeightUnit.kilograms) == 100)
        #expect(isClose(UnitConversion.convertWeightToKg(220.462, from: ExerciseWeightUnit.pounds), 100))
    }

    /// Converting between the same unit must not go through kilograms and back, which would leave
    /// a weight a rounding error away from what was typed.
    @Test("Test Converting Between The Same Weight Unit Changes Nothing")
    func testConvertingBetweenTheSameWeightUnitChangesNothing() {
        #expect(UnitConversion.convertWeight(137.5, from: .pounds, into: .pounds) == 137.5)
        #expect(UnitConversion.convertWeight(137.5, from: .kilograms, into: .kilograms) == 137.5)
    }

    @Test("Test Converting Between Weight Units")
    func testConvertingBetweenWeightUnits() {
        #expect(isClose(UnitConversion.convertWeight(100, from: .kilograms, into: .pounds), 220.462))
        #expect(isClose(UnitConversion.convertWeight(220.462, from: .pounds, into: .kilograms), 100))
    }

    @Test("Test The User's Weight Preference Converts The Same Way")
    func testTheUsersWeightPreferenceConvertsTheSameWay() {
        #expect(UnitConversion.convertWeight(72.5, to: WeightUnitPreference.kilograms) == 72.5)
        #expect(isClose(
            UnitConversion.convertWeight(72.5, to: WeightUnitPreference.pounds),
            UnitConversion.kgToLbs(72.5)
        ))
        #expect(isClose(UnitConversion.convertWeightToKg(159.83, from: WeightUnitPreference.pounds), 72.5, within: 0.01))
    }

    // MARK: - Length

    @Test("Test Centimetres To Inches")
    func testCentimetresToInches() {
        #expect(isClose(UnitConversion.cmToInches(2.54), 1))
        #expect(isClose(UnitConversion.cmToInches(100), 39.3700787))
    }

    @Test("Test Inches To Centimetres")
    func testInchesToCentimetres() {
        #expect(isClose(UnitConversion.inchesToCm(1), 2.54))
        #expect(isClose(UnitConversion.inchesToCm(39.3700787), 100))
    }

    @Test("Test Length Round Trips Through Centimetres")
    func testLengthRoundTripsThroughCentimetres() {
        for inches in [12.0, 32.5, 40.0] {
            let stored = UnitConversion.inchesToCm(inches)
            #expect(isClose(UnitConversion.cmToInches(stored), inches))
        }
    }

    @Test("Test Converting Length To The User's Preference")
    func testConvertingLengthToTheUsersPreference() {
        #expect(UnitConversion.convertLength(180, to: .centimeters) == 180)
        #expect(isClose(UnitConversion.convertLength(180, to: .inches), 70.8661417))
        #expect(UnitConversion.convertLengthToCm(180, from: .centimeters) == 180)
        #expect(isClose(UnitConversion.convertLengthToCm(70.8661417, from: .inches), 180))
    }

    // MARK: - Distance

    @Test("Test Metres To Miles")
    func testMetresToMiles() {
        #expect(isClose(UnitConversion.metersToMiles(1609.344), 1, within: 0.001))
        #expect(UnitConversion.metersToMiles(0) == 0)
    }

    @Test("Test Distance Round Trips Through Metres")
    func testDistanceRoundTripsThroughMetres() {
        for miles in [1.0, 3.1, 13.1, 26.2] {
            let stored = UnitConversion.milesToMeters(miles)
            #expect(isClose(UnitConversion.metersToMiles(stored), miles))
        }
    }

    @Test("Test Converting Between The Same Distance Unit Changes Nothing")
    func testConvertingBetweenTheSameDistanceUnitChangesNothing() {
        #expect(UnitConversion.convertDistance(5000, from: .meters, into: .meters) == 5000)
        #expect(UnitConversion.convertDistance(3.1, from: .miles, into: .miles) == 3.1)
    }

    @Test("Test Converting Between Distance Units")
    func testConvertingBetweenDistanceUnits() {
        #expect(isClose(UnitConversion.convertDistance(1609.344, from: .meters, into: .miles), 1, within: 0.001))
        #expect(isClose(UnitConversion.convertDistance(1, from: .miles, into: .meters), 1609.344, within: 0.01))
    }

    // MARK: - Formatting

    @Test("Test Weight Formats To One Decimal Place")
    func testWeightFormatsToOneDecimalPlace() {
        #expect(UnitConversion.formatWeight(72.456, unit: ExerciseWeightUnit.kilograms) == "72.5")
        #expect(UnitConversion.formatWeight(0, unit: ExerciseWeightUnit.kilograms) == "0.0")
    }

    /// Metres switch to kilometres past 1,000 so a 5 km run does not read as "5000 m", while miles
    /// always keep two decimals.
    @Test("Test Distance Formats By Size")
    func testDistanceFormatsBySize() {
        #expect(UnitConversion.formatDistance(400, unit: .meters) == "400 m")
        #expect(UnitConversion.formatDistance(999, unit: .meters) == "999 m")
        #expect(UnitConversion.formatDistance(1000, unit: .meters) == "1.00 km")
        #expect(UnitConversion.formatDistance(5000, unit: .meters) == "5.00 km")
        #expect(UnitConversion.formatDistance(1609.344, unit: .miles) == "1.00")
    }

    // MARK: - Abbreviations
    //
    // These label the values above, so a chart showing kilograms under a "lb" axis is a bug this
    // pairing is meant to make obvious.

    @Test("Test Unit Abbreviations")
    func testUnitAbbreviations() {
        #expect(ExerciseWeightUnit.kilograms.abbreviation == "kg")
        #expect(ExerciseWeightUnit.pounds.abbreviation == "lb")
        #expect(ExerciseDistanceUnit.meters.abbreviation == "m")
        #expect(ExerciseDistanceUnit.miles.abbreviation == "mi")
    }
}
