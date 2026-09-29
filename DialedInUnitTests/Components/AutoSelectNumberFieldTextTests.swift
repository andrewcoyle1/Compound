//
//  AutoSelectNumberFieldTextTests.swift
//  DialedInUnitTests
//

import Testing
@testable import DialedIn

/// What a set row's weight and reps fields show for a stored value.
struct AutoSelectNumberFieldTextTests {

    @Test("Test Whole Numbers Drop The Trailing Zero")
    func testWholeNumbersDropTheTrailingZero() {
        #expect(AutoSelectNumberField.text(for: 10) == "10")
        #expect(AutoSelectNumberField.text(for: 40) == "40")
        #expect(AutoSelectNumberField.text(for: 0) == "0")
    }

    @Test("Test Fractions Keep Their Decimal Point")
    func testFractionsKeepTheirDecimalPoint() {
        #expect(AutoSelectNumberField.text(for: 42.5) == "42.5")
        #expect(AutoSelectNumberField.text(for: 2.25) == "2.25")
    }

    /// The text goes back through `Double(_:)` on every edit, so it must parse to the same value.
    @Test("Test The Text Parses Back To The Same Value")
    func testTheTextParsesBackToTheSameValue() {
        for value in [0, 8, 42.5, 102.25, 1e20] {
            #expect(Double(AutoSelectNumberField.text(for: value)) == value)
        }
    }
}
