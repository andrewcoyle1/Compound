//
//  DecimalWheelValueTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 29/09/2026.
//

import Testing
@testable import Compound

/// `DecimalWheelValue` backs the tenths wheel on Log Weight and Log Measurement (HIG decision
/// 11b): a whole-number wheel plus a tenths wheel, combined into one decimal value.
struct DecimalWheelValueTests {

    @Test("Splits a value with no rounding needed")
    func splitsExactTenth() {
        let (whole, tenths) = DecimalWheelValue.split(82.4)
        #expect(whole == 82)
        #expect(tenths == 4)
    }

    @Test("A whole-number entry saved before the tenths wheel existed splits to tenths of 0")
    func splitsWholeNumber() {
        let (whole, tenths) = DecimalWheelValue.split(82.0)
        #expect(whole == 82)
        #expect(tenths == 0)
    }

    @Test("Rounds to the nearest tenth rather than truncating")
    func splitsRoundsToNearestTenth() {
        let (whole, tenths) = DecimalWheelValue.split(82.449)
        #expect(whole == 82)
        #expect(tenths == 4)
    }

    @Test("A tenths carry rolls into the whole number, never a tenths digit of 10")
    func splitsCarriesIntoWhole() {
        let (whole, tenths) = DecimalWheelValue.split(9.96)
        #expect(whole == 10)
        #expect(tenths == 0)
    }

    @Test("Combine is the inverse of split")
    func combineIsInverseOfSplit() {
        #expect(DecimalWheelValue.combine(whole: 82, tenths: 4) == 82.4)
        #expect(DecimalWheelValue.combine(whole: 82, tenths: 0) == 82.0)
    }

    @Test("Round trips through split and combine")
    func roundTrips() {
        for value in [30.0, 82.4, 99.9, 100.0, 154.7, 200.0] {
            let (whole, tenths) = DecimalWheelValue.split(value)
            #expect(DecimalWheelValue.combine(whole: whole, tenths: tenths) == value)
        }
    }
}
