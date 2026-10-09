//
//  MethodInfo+Habits.swift
//  Compound
//
//  Habits and everyday targets: the weekly session goal and its streak, the daily step goal, the
//  band a day's calories count as on target, and the waist ratios' screening bands.
//

import Foundation

// Each summary is one localized sentence group, kept on one line so it extracts as one string.
// swiftlint:disable line_length
extension MethodInfo {
    static var allHabits: [MethodInfo] {
        [weeklySessionGoal, dailyStepGoal, calorieAdherenceBand, waistToHeightRatio, waistToHipRatio]
    }

    static let weeklySessionGoal = MethodInfo(
        id: "habits.weeklyGoal",
        title: "Weekly Goal and Streak",
        summary: "Your streak is the number of weeks in a row you met your weekly session goal. The week still under way never breaks it. The goal starts at 3 sessions a week and can be set from 1 to 7. The WHO and ACSM guidelines recommend muscle-strengthening work on at least 2 days a week. In habit research, missing a single opportunity did not materially set back forming the habit, and the habit kept strengthening for about two months.",
        formula: """
        week met = sessions in the week ≥ goal
        streak = consecutive met weeks, this week included once met
        default goal 3; range 1–7
        """,
        limitations: "Habit studies follow groups over weeks to months; how long a habit takes varies widely between people. A streak measures consistency, not progress.",
        ownChoices: "The default of 3 sessions a week and the 1–7 range are Compound's own choices. Only the floor of 2 days a week comes from the guidelines.",
        citations: [.bull2020, .currier2026, .lally2010]
    )

    static let dailyStepGoal = MethodInfo(
        id: "habits.stepGoal",
        title: "Daily Step Goal",
        summary: "Unless you choose your own goal, it is 8,000 steps a day, or 7,000 from age 60. In pooled cohort studies, the risk of dying early stopped falling at about 8,000–10,000 steps a day under 60, and at about 6,000–8,000 from 60. A later meta-analysis found most of the benefit by about 7,000 steps compared with 2,000.",
        formula: """
        goal = your chosen goal, else
               8,000 steps/day under 60
               7,000 steps/day from 60
        """,
        limitations: "These are observational studies: people who walk more differ in other ways too, so the figures show association, not cause. Phones and watches count steps differently.",
        ownChoices: "The exact defaults of 8,000 and 7,000 are Compound's own picks within the ranges the studies found.",
        citations: [.paluch2022, .ding2025]
    )

    static let calorieAdherenceBand = MethodInfo(
        id: "habits.adherenceBand",
        title: "On-Target Band",
        summary: "A day's calories count as on target when they land within 10% either side of that day's target. Protein counts once you reach its target. US food labels may understate calories by up to 20% before a product counts as misbranded, so a tighter band would mostly measure label error rather than your eating.",
        formula: """
        calories on target: |eaten − target| ≤ 10% × target
        protein on target: eaten ≥ target
        """,
        limitations: "No study validates a particular band width. Logging errors and label errors both feed into the figure.",
        ownChoices: "The 10% band is Compound's own choice, sized to sit inside typical food-label error.",
        citations: [.cfr21]
    )

    static let waistToHeightRatio = MethodInfo(
        id: "habits.waistToHeight",
        title: "Waist-to-Height Ratio",
        summary: "Your waist divided by your height, both in centimeters, from the same day's waist measurement and your profile height. NICE uses it to screen for central fat: 0.40 to 0.49 is the healthy range (keep your waist to less than half your height), 0.50 to 0.59 is increased risk and 0.60 or more is high risk. The bands apply to all sexes and ethnicities, including people with a lot of muscle. This is screening, not a diagnosis.",
        formula: """
        ratio = waist (cm) ÷ height (cm)
        < 0.50       under half your height (0.40–0.49 healthy)
        0.50–0.59    increased risk
        ≥ 0.60       high risk
        """,
        limitations: "NICE gives these bands for people with a BMI under 35. Whether NICE sets a band below 0.40 could not be confirmed, so Compound shows none. A tape measurement can vary by a centimeter or two with where and how it is taken.",
        citations: [.niddk2025]
    )

    static let waistToHipRatio = MethodInfo(
        id: "habits.waistToHip",
        title: "Waist-to-Hip Ratio",
        summary: "Your waist divided by your hips, from measurements logged on the same day. A WHO expert consultation marks a substantially increased risk of metabolic complications from 0.90 in men and 0.85 in women. Compound uses the cut-off for the sex in your profile, and shows both when it is not set. This is screening, not a diagnosis.",
        formula: """
        ratio = waist (cm) ÷ hip (cm)
        substantially increased risk: ≥ 0.90 (men), ≥ 0.85 (women)
        """,
        limitations: "The cut-offs come from population studies and were not set for any one ethnicity or for very muscular people. Waist-to-height is the better-supported ratio for lifters.",
        citations: [.who2011, .niddk2025]
    )
}
// swiftlint:enable line_length
