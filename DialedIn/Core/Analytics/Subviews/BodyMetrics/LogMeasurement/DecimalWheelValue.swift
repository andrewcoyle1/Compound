//
//  DecimalWheelValue.swift
//  DialedIn
//
//  Created by Andrew Coyle on 29/09/2026.
//

import Foundation

/// Combines and splits a value shown as two wheel columns — whole units and tenths — so 82.4 kg or
/// 172.3 cm can be entered without a decimal keypad. Log Weight and Log Measurement both use this,
/// in kilograms/pounds and centimetres/inches respectively.
enum DecimalWheelValue {

    /// The tenths wheel's range, ascending like every other wheel here (S: finding 1's "wheels list
    /// values in descending order" applies to the whole-number wheels too — see their `ForEach`).
    static let tenths = 0...9

    /// Rounds to the nearest tenth and splits into a whole part and a 0...9 tenths digit, carrying
    /// 9.96 → (10, 0) rather than a tenths digit of 10.
    static func split(_ value: Double) -> (whole: Int, tenths: Int) {
        let scaledTenths = Int((value * 10).rounded())
        return (scaledTenths / 10, scaledTenths % 10)
    }

    /// The inverse of `split`.
    static func combine(whole: Int, tenths: Int) -> Double {
        Double(whole) + Double(tenths) / 10
    }
}
