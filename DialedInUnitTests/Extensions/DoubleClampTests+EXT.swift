//
//  DoubleClampTests+EXT.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

// The two helpers that exist because `max(value, floor)` kept being written where a clamp was
// meant. Six crashes of that shape have been fixed in this app, all of them the same: a NaN or an
// infinity survived the floor, reached an `Int(_:)` inside a SwiftUI view body, and trapped while
// the screen was drawing.
//
// These tests are mostly about what the naive spelling gets wrong, so each one states the value
// `max`/`min` alone would have produced.
struct DoubleClampTests {

    // MARK: - Clamping a stored figure

    /// The case the helper exists for. `max(.nan, 30)` is `.nan`, not 30: `max` is
    /// `y >= x ? y : x`, and `30 >= .nan` is false, so the NaN is handed straight back.
    @Test("Test NaN Falls Back Rather Than Surviving The Floor")
    func testNaNFallsBackRatherThanSurvivingTheFloor() {
        #expect(Double.nan.clamped(to: 30...500, whenNotFinite: 70) == 70)
        #expect(max(Double.nan, 30).isNaN, "the spelling this replaces")
    }

    /// A one-sided floor leaves the top open, and an infinity is above every floor to begin with.
    @Test("Test Either Infinity Falls Back")
    func testEitherInfinityFallsBack() {
        #expect(Double.infinity.clamped(to: 30...500, whenNotFinite: 70) == 70)
        #expect((-Double.infinity).clamped(to: 30...500, whenNotFinite: 70) == 70)
    }

    /// A number the arithmetic can survive is not to be touched — the whole point is that a
    /// well-formed profile computes exactly as it did before.
    @Test("Test A Usable Number Passes Through Untouched")
    func testAUsableNumberPassesThroughUntouched() {
        #expect(80.5.clamped(to: 30...500, whenNotFinite: 70) == 80.5)
        #expect(30.0.clamped(to: 30...500, whenNotFinite: 70) == 30)
        #expect(500.0.clamped(to: 30...500, whenNotFinite: 70) == 500)
    }

    /// Out of range is not the same as unusable: a real number outside the bounds is pulled to the
    /// nearest one rather than replaced by the fallback.
    @Test("Test A Finite Number Outside The Range Is Pulled To The Nearest Bound")
    func testAFiniteNumberOutsideTheRangeIsPulledToTheNearestBound() {
        #expect(10.0.clamped(to: 30...500, whenNotFinite: 70) == 30)
        #expect(9_000.0.clamped(to: 30...500, whenNotFinite: 70) == 500)
    }

    // MARK: - Reading a typed amount

    /// The reason a text field is dangerous: `Double`'s string initialiser parses all of these.
    @Test("Test The Words That Parse As Numbers Read As Zero")
    func testTheWordsThatParseAsNumbersReadAsZero() {
        for typed in ["nan", "NaN", "inf", "-inf", "infinity", "-Infinity"] {
            #expect(Double(typed) != nil, "\(typed) parses, which is the problem")
            #expect(Double.enteredAmount(typed) == 0)
        }
    }

    /// No letters needed: a literal too large for a `Double` overflows to infinity on parsing.
    @Test("Test An Overflowing Literal Reads As Zero")
    func testAnOverflowingLiteralReadsAsZero() {
        #expect(Double("1e400") == .infinity)
        #expect(Double.enteredAmount("1e400") == 0)
    }

    /// Text that is not a number at all was already zero, and stays zero.
    @Test("Test Text That Is Not A Number Reads As Zero")
    func testTextThatIsNotANumberReadsAsZero() {
        #expect(Double.enteredAmount("abc") == 0)
        #expect(Double.enteredAmount("") == 0)
    }

    /// A negative amount would subtract food from the day, which is what the floor these call
    /// sites already carried was for.
    @Test("Test A Negative Amount Reads As Zero")
    func testANegativeAmountReadsAsZero() {
        #expect(Double.enteredAmount("-50") == 0)
    }

    /// Anything a person could plausibly type is theirs, to the digit.
    @Test("Test A Real Amount Is Read Exactly")
    func testARealAmountIsReadExactly() {
        #expect(Double.enteredAmount("0") == 0)
        #expect(Double.enteredAmount("2.5") == 2.5)
        #expect(Double.enteredAmount("1250") == 1250)
    }

    /// A finite but absurd figure is capped, because multiplying it into a per-100g nutrient is
    /// how a finite number becomes an infinite one.
    @Test("Test An Absurd But Finite Amount Is Capped")
    func testAnAbsurdButFiniteAmountIsCapped() {
        let capped = Double.enteredAmount("1e300")

        #expect(capped.isFinite)
        #expect((capped * 900 / 100).isFinite)
    }

    // MARK: - Typed with the region's separator

    /// The decimal pad in Germany, Spain or Brazil has a comma and no full stop. `Double("1,5")`
    /// is nil, so every amount read as zero and Log stayed disabled.
    @Test("A decimal comma is read as a decimal point")
    func testADecimalCommaIsReadAsADecimalPoint() {
        let german = Locale(identifier: "de_DE")

        #expect(Double.typed("1,5", locale: german) == 1.5)
        #expect(Double.typed("1.5", locale: german) == 1.5)
        #expect(Double.typed("1,5", locale: Locale(identifier: "en_GB")) == 1.5)
        #expect(Double.enteredAmount("0,25") == 0.25)
    }

    @Test("Digits in another script are read as numbers")
    func testDigitsInAnotherScriptAreReadAsNumbers() {
        #expect(Double.typed("١٫٥", locale: Locale(identifier: "ar_SA")) == 1.5)
    }

    @Test("A grouped figure and a non-number are still rejected")
    func testAGroupedFigureAndANonNumberAreStillRejected() {
        #expect(Double.typed("1,234.5") == nil)
        #expect(Double.typed("nan") == nil)
        #expect(Double.typed("inf") == nil)
        #expect(Double.typed("") == nil)
    }
}
