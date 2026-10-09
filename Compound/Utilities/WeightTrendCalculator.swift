//
//  WeightTrendCalculator.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import Foundation

/// How the app reads a scale: the noise on one weigh-in and what to do with one that disagrees with
/// the trend. Shared by the trend line (`WeightTrendCalculator`) and the expenditure filter
/// (`ExpenditureFilter`), so the chart and the engine treat every reading the same way.
///
/// Sources: the 0.5% noise is Schneditz 2023's 0.53% day-to-day SD of body mass (R30). Everything
/// marked "design choice" has no paper behind the exact value and is to be tuned by replaying
/// users' histories. See `MethodInfo.weightTrend`.
enum WeighInNoise {

    /// R_W = (0.5% of body weight)²: one weigh-in's SD as a share of the weight.
    static let noiseFraction: Double = 0.005

    // MARK: Design choices — tune by replay

    /// The weigh-in SD never drops below 0.3 kg, however light the person.
    static let noiseFloorKg: Double = 0.3
    /// q_L: real day-to-day level shifts (water, glycogen) the trend may follow, as an SD per day.
    static let levelNoiseKgPerDay: Double = 0.05
    /// Huber threshold, in predicted SDs of the innovation.
    static let huberThreshold: Double = 2.5
    /// A reading further than max(3 kg, 4% of the trend) from it is held until the next one agrees.
    static let grossErrorKg: Double = 3
    static let grossErrorFraction: Double = 0.04
    /// The trend starts at the median of this many first weigh-ins, so one odd first reading does
    /// not anchor it.
    static let seedWeighIns: Int = 3

    // MARK: Rules

    /// The variance of one weigh-in at this trend weight.
    static func variance(levelKg: Double) -> Double {
        max(pow(noiseFraction * levelKg, 2), noiseFloorKg * noiseFloorKg)
    }

    /// True when a reading is so far from the trend that it is more likely a typo or a different
    /// scale than a real change, and should wait for the next weigh-in to confirm it.
    static func isGrossError(innovation: Double, levelKg: Double) -> Bool {
        abs(innovation) > max(grossErrorKg, grossErrorFraction * levelKg)
    }

    /// The Huber-type robust variance: a reading beyond the threshold has its variance inflated by
    /// the square of how far beyond it is, so it pulls the trend no harder than one at the threshold.
    /// This replaces the old ±2.5% clamp.
    static func robustVariance(innovation: Double, predictedVariance: Double, levelKg: Double) -> Double {
        let noise = variance(levelKg: levelKg)
        let ratio = abs(innovation) / (huberThreshold * (predictedVariance + noise).squareRoot())
        return noise * max(1, ratio * ratio)
    }

    /// The median, or nil for no values.
    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
    }
}

/// The weight trend: one local-linear-trend Kalman filter (level and slope) run over the weigh-ins
/// with the real gap in days between them, a robust update for odd readings, and a
/// Rauch-Tung-Striebel smoothing pass so the chart's past points use the readings after them.
///
/// It replaced a 0.25-per-weigh-in moving average whose smoothing depended on how often someone
/// weighed in. The filter's time constant is in days, so weighing daily or weekly reads the same.
/// For someone who never logs food, this is exactly what the expenditure filter reduces to.
enum WeightTrendCalculator {

    // MARK: Design choices — tune by replay

    /// The slope's random walk per day, about (q_E + q_T)/ρ² of the expenditure filter, which gives
    /// a 7–10 day smoothing time constant at daily weighing (Hacker's Diet, R39).
    static let slopeNoiseKgPerDay: Double = 0.004
    /// The starting slope's SD, kg per day.
    static let initialSlopeSDKgPerDay: Double = 0.1

    /// The trend at each input date, smoothed with everything after it. One point per input.
    ///
    /// - Parameters:
    ///   - data: Weigh-ins sorted by date. Only the first of each calendar day moves the trend;
    ///     later ones that day get the same value.
    ///   - calendar: Decides which readings share a day and how many days lie between them.
    static func trend(
        data: [(date: Date, value: Double)],
        calendar: Calendar = .current
    ) -> [(date: Date, value: Double)] {
        guard let first = data.first else { return [] }
        let firstDay = calendar.startOfDay(for: first.date)
        let dayIndex = data.map { entry in
            calendar.dateComponents([.day], from: firstDay, to: calendar.startOfDay(for: entry.date)).day ?? 0
        }
        let values = data.map(\.value)
        let levels = smoothedLevels(values: values, dayIndex: dayIndex)
        return zip(data, levels).map { (date: $0.0.date, value: $0.1) }
    }

    /// Kept for the callers written against the old moving average: it now returns `trend(data:)`.
    static func exponentialMovingAverage(
        data: [(date: Date, value: Double)]
    ) -> [(date: Date, value: Double)] {
        trend(data: data)
    }

    // MARK: - The filter

    /// Level-slope state with its covariance [P_LL, P_Lb, P_bb].
    private struct State {
        var level: Double
        var slope: Double
        var pLL: Double
        var pLb: Double
        var pbb: Double
    }

    /// Filters forward, then smooths backward. `dayIndex` is each value's day, counted from the
    /// first; equal neighbours are the same day.
    static func smoothedLevels(values: [Double], dayIndex: [Int]) -> [Double] {
        let count = min(values.count, dayIndex.count)
        guard count > 0 else { return [] }
        let isFirstOfDay: (Int) -> Bool = { index in index == 0 || dayIndex[index] != dayIndex[index - 1] }

        let seed = (0..<count).filter(isFirstOfDay).prefix(WeighInNoise.seedWeighIns).map { values[$0] }
        let start = WeighInNoise.median(Array(seed)) ?? values[0]
        var state = State(
            level: start,
            slope: 0,
            pLL: WeighInNoise.variance(levelKg: start),
            pLb: 0,
            pbb: initialSlopeSDKgPerDay * initialSlopeSDKgPerDay
        )

        var filtered: [State] = []
        var predicted: [State] = []
        var gaps: [Double] = []
        var held: Double?
        var lastDay = dayIndex[0]

        for index in 0..<count {
            let gap = Double(dayIndex[index] - lastDay)
            lastDay = dayIndex[index]
            state = predict(state, gap: gap)
            predicted.append(state)
            gaps.append(gap)
            if index > 0 && isFirstOfDay(index) {
                observe(values[index], state: &state, predicted: &predicted[index], held: &held)
            }
            filtered.append(state)
        }

        return rauchTungStriebel(filtered: filtered, predicted: predicted, gaps: gaps)
    }

    /// L ← L + b·Δt; P ← F·P·Fᵀ + Q(Δt).
    private static func predict(_ state: State, gap: Double) -> State {
        let slopeNoise = slopeNoiseKgPerDay * slopeNoiseKgPerDay
        let levelNoise = WeighInNoise.levelNoiseKgPerDay * WeighInNoise.levelNoiseKgPerDay
        return State(
            level: state.level + state.slope * gap,
            slope: state.slope,
            pLL: state.pLL + 2 * gap * state.pLb + gap * gap * state.pbb
                + slopeNoise * gap * gap * gap / 3 + levelNoise * gap,
            pLb: state.pLb + gap * state.pbb + slopeNoise * gap * gap / 2,
            pbb: state.pbb + slopeNoise * gap
        )
    }

    /// One weigh-in: a robust update, or held as a probable error until the next one agrees.
    private static func observe(_ weight: Double, state: inout State, predicted: inout State, held: inout Double?) {
        let innovation = weight - state.level
        let noise: Double
        if !WeighInNoise.isGrossError(innovation: innovation, levelKg: state.level) {
            held = nil
            noise = WeighInNoise.robustVariance(innovation: innovation, predictedVariance: state.pLL, levelKg: state.level)
        } else if let previous = held, (previous > 0) == (innovation > 0) {
            // A second reading off the same way confirms a real shift (a new scale, a bigger change
            // than usual). Open the level up to it as process noise, so the smoother does not drag
            // earlier points across the step.
            held = nil
            state.pLL += innovation * innovation
            predicted = state
            noise = WeighInNoise.variance(levelKg: state.level)
        } else {
            held = innovation
            return
        }
        let total = state.pLL + noise
        let levelGain = state.pLL / total
        let slopeGain = state.pLb / total
        state = State(
            level: state.level + levelGain * innovation,
            slope: state.slope + slopeGain * innovation,
            pLL: (1 - levelGain) * state.pLL,
            pLb: (1 - levelGain) * state.pLb,
            pbb: state.pbb - slopeGain * state.pLb
        )
    }

    /// The backward pass: x(k|n) = x(k|k) + C·(x(k+1|n) − x(k+1|k)), C = P(k|k)·Fᵀ·P(k+1|k)⁻¹.
    private static func rauchTungStriebel(filtered: [State], predicted: [State], gaps: [Double]) -> [Double] {
        let count = filtered.count
        guard count > 0 else { return [] }
        var levels = filtered.map(\.level)
        var nextLevel = filtered[count - 1].level
        var nextSlope = filtered[count - 1].slope
        guard count > 1 else { return levels }

        for index in stride(from: count - 2, through: 0, by: -1) {
            let current = filtered[index]
            let ahead = predicted[index + 1]
            let gap = gaps[index + 1]
            // P(k|k)·Fᵀ with F = [[1, gap], [0, 1]].
            let a00 = current.pLL + gap * current.pLb
            let a01 = current.pLb
            let a10 = current.pLb + gap * current.pbb
            let a11 = current.pbb
            let det = ahead.pLL * ahead.pbb - ahead.pLb * ahead.pLb
            guard det > 0 else {
                nextLevel = current.level
                nextSlope = current.slope
                continue
            }
            let inv00 = ahead.pbb / det
            let inv01 = -ahead.pLb / det
            let inv11 = ahead.pLL / det
            let c00 = a00 * inv00 + a01 * inv01
            let c01 = a00 * inv01 + a01 * inv11
            let c10 = a10 * inv00 + a11 * inv01
            let c11 = a10 * inv01 + a11 * inv11
            let levelDiff = nextLevel - ahead.level
            let slopeDiff = nextSlope - ahead.slope
            nextLevel = current.level + c00 * levelDiff + c01 * slopeDiff
            nextSlope = current.slope + c10 * levelDiff + c11 * slopeDiff
            levels[index] = nextLevel
        }
        return levels
    }
}
