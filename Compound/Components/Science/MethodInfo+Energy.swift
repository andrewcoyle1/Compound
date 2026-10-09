//
//  MethodInfo+Energy.swift
//  Compound
//
//  The weight trend, adaptive expenditure, the energy in a kilogram, the energy balance, the
//  calorie-target proposal and the weekly check-in's rules. The code they describe is
//  `WeightTrendCalculator`, `ExpenditureFilter`, `ExpenditureEngine`, `EnergyDensity`,
//  `EnergyBalanceSummary`, `TargetProposal` and `CheckInPresenter`.
//

import Foundation

// Each summary is one localized sentence group, kept on one line so it extracts as one string.
// swiftlint:disable line_length
extension MethodInfo {
    static var allEnergy: [MethodInfo] {
        [weightTrend, adaptiveExpenditure, energyDensity, energyBalance, targetProposal, checkInRules]
    }

    static let weightTrend = MethodInfo(
        id: "weight-trend",
        title: "Weight Trend",
        summary: "Your trend weight is what your weight is doing once day-to-day water and food swings are filtered out. Compound runs a Kalman filter over your weigh-ins that tracks a level and a rate of change, and uses the real number of days between readings, so weighing daily or weekly gives the same kind of line. Each weigh-in is assumed to carry about half a percent of your body weight in noise. A reading that disagrees with the trend counts for less the further off it is, and one more than 3 kg (or 4%) away is set aside unless your next weigh-in agrees with it. Only your first weigh-in of a day counts. On the chart, each past point is also smoothed using the readings that came after it.",
        formula: """
        State: level L (kg), slope b (kg/day). Between weigh-ins Δt days apart:
          L ← L + b·Δt
          P ← F·P·Fᵀ + Q,  F = [[1, Δt], [0, 1]]
          Q = 0.004²·[[Δt³/3, Δt²/2], [Δt²/2, Δt]] + diag(0.05²·Δt, 0)
        Weigh-in y: v = y − L,  R = max((0.005·L)², 0.3²),  S = P_LL + R
          R_eff = R·max(1, (|v| / (2.5·√S))²)       (robust, Huber-type)
          |v| > max(3 kg, 0.04·L): held until the next weigh-in agrees
          K = P[:,0] / (P_LL + R_eff);  x ← x + K·v
        Start: L = median of the first 3 weigh-ins, b = 0 (SD 0.1 kg/day)
        Chart: Rauch–Tung–Striebel smoother over the whole series
        """,
        limitations: "Body weight also follows a weekly rhythm (higher after weekends) and, for some people, the menstrual cycle; the filter does not model either, so the trend can drift a little with them. The 0.5% noise figure comes from a long series of daily weighings in one person, so your own scale and routine may be noisier or quieter.",
        ownChoices: "The 0.3 kg noise floor, the 0.05 kg/day level noise, the 0.004 kg/day slope noise, the 2.5 robust threshold, the max(3 kg, 4%) hold rule, the median-of-three start and using the first weigh-in of the day are Compound's own choices, to be tuned on real histories.",
        citations: [.schneditz2023, .orsama2014, .turicchi2020, .walker, .rauch1965]
    )

    static let adaptiveExpenditure = MethodInfo(
        id: "adaptive-expenditure",
        title: "Adaptive Expenditure",
        summary: "Your expenditure (TDEE) is learned from what you log and what the scale does. One Kalman filter, updated every day, tracks three things: your trend weight, your usual intake and your expenditure. Each day your trend weight moves by the difference between intake and expenditure, divided by the energy in a kilogram. Weigh-ins correct the trend; completely logged days correct your usual intake; together they reveal expenditure. Days you did not log, marked as incomplete, spent on a logging break, or logged at under half your expenditure (unless you marked a fast) are not read as intake: the filter only becomes less sure. It starts from your profile's formula estimate and shows that figure while it is still calibrating. Because it learns from your logs, it is based on what you logged: if you consistently under-log, it reads lower by the same amount, and targets built on it still work.",
        formula: """
        State x = [L (kg), E (kcal/d), T (kcal/d)], one step per day:
          L ← L + (E − T)/ρ        ρ = energy per kg (see Energy in a kilogram)
          process SDs per day: L 0.05 kg, E 30 kcal, T 13 kcal
        Weigh-in observes L (weight trend rules); complete logged day observes E:
          σ_I = SD of your logged days in the last 28, held in 300–500 kcal
                (400 with fewer than 7), ×2 if under 60% of days are logged
          a day below 0.5·T is skipped unless marked as a fast
        Start: T = E = formula, SD(T) = max(0.15·formula, 340), SD(E) = 500
        Calibrating until: ≥21 days, ≥14 weigh-ins, √P_TT < 200 kcal and ≥80% of the
          last 28 days logged. Until then the formula figure is shown.
        Shown: clamp(T, 0.6·formula, 1.6·formula) + step nowcast
        80% interval: T ± 1.28·√P_TT
        Step nowcast (optional): (mean steps last 7 d − mean steps last 28 d)
          × 0.0004 kcal/step/kg × trend weight, capped at ±300 kcal
        """,
        limitations: "Even with daily weights and complete logs, weight-based estimates of an individual's energy balance were off by about 200 kcal a day in a two-year trial, and around four weeks of daily weigh-ins are needed for a usable estimate. Logging that changes in accuracy (more careful after a stall), or unlogged days that differ from logged ones (weekends), will bias it. No study has validated an app's Kalman expenditure estimate against doubly labeled water.",
        ownChoices: "The three-part filter itself, its process noises (0.05 kg, 30 kcal and 13 kcal a day), the 300–500 kcal intake noise and its doubling below 60% logged, the half-of-expenditure partial-day rule, the starting SDs, the calibration gate (21 days, 14 weigh-ins, SD under 200 kcal, 80% logged), the 60–160% guard, the 80% interval, and the step nowcast's 300 kcal cap and 1,300–1,400 steps per km behind its 0.0004 constant are Compound's own choices, to be tuned on real histories.",
        citations: [.hall2011b, .sanghvi2015, .guo2020, .guo2017, .nasem2023, .lichtman1992, .martins2020, .nunes2022b, .acsm2021]
    )

    static let energyDensity = MethodInfo(
        id: "energy-density",
        title: "Energy in a Kilogram",
        summary: "Turning a change in weight into calories needs the energy in a kilogram of body weight. That depends on how much of the change is fat: the leaner you are, the more of each kilogram is lean tissue, which holds far less energy. With a body fat reading from the last 90 days, Compound splits the change between fat and lean tissue by Forbes' curve; without one it uses the conventional 7,700 kcal per kilogram, which fits someone carrying roughly 35 kg of fat. The same figure is used for your expenditure estimate and your targets.",
        formula: """
        F = weight × body fat % / 100   (kg of fat)
        p = F / (F + 10.4)              share of a change that is fat (Forbes)
        ρ = p·9,440 + (1 − p)·1,816     kcal per kg
        No body fat reading: ρ = 7,700
        F = 15 kg → ρ ≈ 6,300;  25 kg → ≈ 7,200;  35 kg → ≈ 7,700
        """,
        limitations: "For a lean lifter the conventional 7,700 overstates the energy in a kilogram by roughly 20–30%. The first few weeks of a diet lose glycogen and water, which hold much less energy (about 4,900 kcal per kg at four weeks), so early weight change looks bigger than the energy behind it. Home body fat scales can be several percentage points out. Inside the feedback loop the figure largely cancels out of your targets; it matters most for the expenditure number shown.",
        ownChoices: "Treating a body fat reading from the last 90 days as trustworthy is Compound's own choice: the app cannot tell a DEXA scan from a bathroom scale.",
        citations: [.hall2008, .hall2011, .hall2007, .forbes1987, .wishnofsky1958, .heymsfield2012, .kreitzman1992]
    )

    static let energyBalance = MethodInfo(
        id: "energy-balance",
        title: "Energy Balance",
        summary: "Energy balance compares what you ate with what your body spent. Expenditure is your adaptive estimate for each day (the formula figure while it calibrates, and held where it was during a logging break). Intake is averaged only over the days you logged: a day with nothing logged is a day the app knows nothing about, not a day you ate nothing, so it is left out and the card says how many days it used.",
        formula: """
        balance = expenditure − mean(intake over logged days)
        positive → deficit, negative → surplus
        expenditure on a day = that day's adaptive estimate
          (last estimate after the history stops; formula before it starts)
        """,
        limitations: "Self-reported intake usually runs below what was really eaten, sometimes by a lot, so a logged deficit can be larger than the real one. The expenditure estimate is learned from the same logs, so the two errors partly cancel, but only if you log consistently.",
        ownChoices: "Counting any day with calories logged as a logged day is Compound's own choice.",
        citations: [.sanghvi2015, .lichtman1992, .hall2011b]
    )

    static let targetProposal = MethodInfo(
        id: "target-proposal",
        title: "Target Suggestions",
        summary: "Your calorie target is your expenditure estimate plus the daily share of your goal's weekly change. Compound suggests a new target at most once a week, only once the estimate has finished calibrating, and only when the new figure differs from your current target by more than the estimate's own uncertainty (and at least 50 kcal). A single suggestion moves at most 150 kcal. There is no separate correction for being off your goal rate: the expenditure estimate already absorbs that, and adding it again would count it twice. If the target would come down but you have been eating more than 10% over it while losing slower than planned, the check-in talks about that instead of lowering a target you are not following. Your calorie floor always applies.",
        formula: """
        target = T + ρ·r/7                 r = goal rate, kg/week (negative to lose)
        target = max(target, calorie floor)
        suggest if |target − current| > max(50, SD of T)
               and the plan is ≥ 7 days old and the estimate is calibrated
        new target = current + clamp(target − current, −150, +150)
        adherence first: if lowering, last week's mean logged intake > 1.10 × current
               and the trend rate is above the goal rate → no change, a note instead
        """,
        limitations: "The structure follows clinical weight-management programs that adjust from observed weight and intake, but no trial has tested these exact thresholds. Weight loss also slows as you get lighter, so holding the rate means the target steps down over time.",
        ownChoices: "The 50 kcal minimum, the uncertainty deadband, the 150 kcal step, the 7-day cadence and the 10% adherence margin are Compound's own choices, to be tuned on real histories. Removing the rate-error correction follows the report's reasoning, not a trial.",
        citations: [.martin2015, .thomas2014, .macrofactor, .hall2011]
    )

    static let checkInRules = MethodInfo(
        id: "check-in-rules",
        title: "Check-In Rules",
        summary: "The weekly check-in cleans up the week before your targets are reviewed. Days you mark as incomplete, and days inside a logging break, are left out of your expenditure estimate's intake but still count as weigh-ins. A day you mark as a fast counts as a real, low intake. Any other day logged at under half your expenditure is read as partly logged and skipped, which is why a fast check-in only asks about those days. It asks for a weigh-in if you have none from the last three days.",
        formula: """
        incomplete or in a break → intake not read; weigh-in still used
        fast → intake read as logged (0 kcal if nothing logged)
        logged < 0.5 × expenditure and not a fast → treated as partial
        weigh-in step shown when the latest weigh-in is > 3 days old
        """,
        limitations: "People under-report intake, and the gap is largest on days that are only partly logged, which is why those days are left out rather than averaged in.",
        ownChoices: "The half-of-expenditure threshold and the three-day weigh-in window are Compound's own choices.",
        citations: [.lichtman1992, .guo2017, .hall2011b]
    )
}
// swiftlint:enable line_length
