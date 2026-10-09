//
//  ExpenditureFilter.swift
//  Compound
//

import Foundation

/// The daily Kalman filter behind adaptive expenditure: three numbers and how sure it is of each.
///
/// - L, the trend weight in kg;
/// - E, the habitual intake in kcal/day, on the scale the user logs;
/// - T, the expenditure (TDEE) in kcal/day, on the same scale.
///
/// Each day L moves by (E − T)/ρ, where ρ is the energy in a kilogram of weight change
/// (`EnergyDensity`). A weigh-in observes L; a complete logged day observes E. With food logs, E is
/// pinned by them and T is what the weight says the body must have spent; without them only E − T,
/// the slope, can be known, and the filter is a plain weight trend. Unlogged days are predicted
/// through and observe nothing, so they widen the uncertainty instead of being imputed.
///
/// The model is the reconciliation in the report's "One filter replaces two EMAs" section; it has
/// no published validation of its own. Process noises are design choices to be tuned by replaying
/// users' histories. Pure value type: no managers, no dates. `functions/coach-maths.js` mirrors it.
struct ExpenditureFilter: Equatable, Sendable {

    // MARK: Design choices — tune by replay

    /// q_E: how far habitual intake may drift in a day, as an SD.
    static let intakeDriftKcalPerDay: Double = 30
    /// q_T: how far expenditure may drift in a day (≈35 kcal a week), as an SD.
    static let expenditureDriftKcalPerDay: Double = 13
    /// The prior on T is the formula, with an SD of the larger of 15% of it and 340 kcal — the
    /// RMSE NASEM 2023 reports for its energy equations.
    static let priorSDFraction: Double = 0.15
    static let priorSDFloorKcal: Double = 340
    /// E starts at the prior with this SD.
    static let initialIntakeSDKcal: Double = 500

    /// [L, E, T].
    private(set) var state: [Double]
    /// Row-major 3×3 covariance.
    private(set) var covariance: [Double]
    /// A gross weigh-in waiting for the next one to confirm it, as its innovation.
    private(set) var heldInnovation: Double?

    var levelKg: Double { state[0] }
    var intakeKcal: Double { state[1] }
    var expenditureKcal: Double { state[2] }
    var expenditureSD: Double { max(0, covariance[8]).squareRoot() }

    /// The trend's rate in kg/day, (E − T)/ρ, and its SD.
    func dailyRate(kcalPerKg: Double) -> (kgPerDay: Double, sdKg: Double) {
        let variance = covariance[4] + covariance[8] - 2 * covariance[5]
        return ((state[1] - state[2]) / kcalPerKg, max(0, variance).squareRoot() / kcalPerKg)
    }

    /// Starts at a trend weight, with E and T both at the formula prior.
    init(levelKg: Double, priorKcal: Double) {
        let priorSD = max(Self.priorSDFloorKcal, Self.priorSDFraction * priorKcal)
        state = [levelKg, priorKcal, priorKcal]
        covariance = [
            WeighInNoise.variance(levelKg: levelKg), 0, 0,
            0, Self.initialIntakeSDKcal * Self.initialIntakeSDKcal, 0,
            0, 0, priorSD * priorSD
        ]
        heldInnovation = nil
    }

    // MARK: - Predict

    /// One day forward: L += (E − T)/ρ, E and T carried, and each gains its process noise.
    mutating func predictOneDay(kcalPerKg: Double) {
        let step = 1 / kcalPerKg
        let transition: [Double] = [1, step, -step, 0, 1, 0, 0, 0, 1]
        var next = Self.multiply(Self.multiply(transition, covariance), Self.transpose(transition))
        next[0] += WeighInNoise.levelNoiseKgPerDay * WeighInNoise.levelNoiseKgPerDay
        next[4] += Self.intakeDriftKcalPerDay * Self.intakeDriftKcalPerDay
        next[8] += Self.expenditureDriftKcalPerDay * Self.expenditureDriftKcalPerDay
        state = [state[0] + (state[1] - state[2]) * step, state[1], state[2]]
        covariance = next
    }

    // MARK: - Observe

    /// A weigh-in. Returns false when the reading is held as a probable error rather than used.
    ///
    /// The same rules as the trend line: a Huber-weighted update, and a reading more than
    /// max(3 kg, 4%) from the trend waits for the next weigh-in to agree before it counts.
    @discardableResult
    mutating func observeWeighIn(_ weightKg: Double) -> Bool {
        let level = state[0]
        let innovation = weightKg - level
        if !WeighInNoise.isGrossError(innovation: innovation, levelKg: level) {
            heldInnovation = nil
            let noise = WeighInNoise.robustVariance(innovation: innovation, predictedVariance: covariance[0], levelKg: level)
            observe(index: 0, value: weightKg, variance: noise)
            return true
        }
        if let held = heldInnovation, (held > 0) == (innovation > 0) {
            heldInnovation = nil
            covariance[0] += innovation * innovation
            observe(index: 0, value: weightKg, variance: WeighInNoise.variance(levelKg: level))
            return true
        }
        heldInnovation = innovation
        return false
    }

    /// A complete logged day's intake, with its noise SD.
    mutating func observeIntake(_ intakeKcal: Double, sdKcal: Double) {
        observe(index: 1, value: intakeKcal, variance: sdKcal * sdKcal)
    }

    /// The scalar Kalman update for an observation of one state component.
    private mutating func observe(index: Int, value: Double, variance: Double) {
        let innovation = value - state[index]
        let total = covariance[index * 4] + variance
        guard total > 0, total.isFinite else { return }
        let gain = [covariance[index], covariance[3 + index], covariance[6 + index]].map { $0 / total }
        let previous = covariance
        state = state.enumerated().map { component, current in current + gain[component] * innovation }
        covariance = previous.enumerated().map { position, current in
            current - gain[position / 3] * previous[index * 3 + position % 3]
        }
    }

    // MARK: - 3×3 arithmetic

    private static func multiply(_ lhs: [Double], _ rhs: [Double]) -> [Double] {
        (0..<9).map { position in
            let row = position / 3
            let column = position % 3
            return lhs[row * 3] * rhs[column] + lhs[row * 3 + 1] * rhs[3 + column] + lhs[row * 3 + 2] * rhs[6 + column]
        }
    }

    private static func transpose(_ matrix: [Double]) -> [Double] {
        [matrix[0], matrix[3], matrix[6], matrix[1], matrix[4], matrix[7], matrix[2], matrix[5], matrix[8]]
    }
}
