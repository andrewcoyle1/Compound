//
//  WeightTrendCalculator.swift
//  DialedIn
//
//  Created by Cursor on 07/02/2026.
//

import Foundation

/// Computes exponential moving average (EWMA) for weight trend smoothing.
/// Industry standard for fitness apps to filter daily fluctuations (water, food timing).
enum WeightTrendCalculator {

    /// α = 2/8 ≈ 0.25 for ~7-day smoothing (responsive but filters noise)
    static let defaultAlpha: Double = 2.0 / 8.0

    /// Computes EWMA trend for weight data.
    /// - Parameters:
    ///   - data: Sorted-by-date weight entries (date, value). Must be non-empty.
    ///   - alpha: Smoothing factor. 2/(n+1) for n-day half-life. Default 2/8 ≈ 7-day.
    /// - Returns: Trend values at each input date (one point per input).
    static func exponentialMovingAverage(
        data: [(date: Date, value: Double)],
        alpha: Double = defaultAlpha
    ) -> [(date: Date, value: Double)] {
        guard !data.isEmpty else { return [] }
        guard data.count > 1 else {
            // Safe: the guard above rules out empty data.
            return [(date: data[0].date, value: data[0].value)]
        }

        var result: [(date: Date, value: Double)] = []
        result.reserveCapacity(data.count)

        var ema = data[0].value
        result.append((date: data[0].date, value: ema))

        for iteration in 1..<data.count {
            ema = alpha * data[iteration].value + (1 - alpha) * ema
            result.append((date: data[iteration].date, value: ema))
        }

        return result
    }
}
