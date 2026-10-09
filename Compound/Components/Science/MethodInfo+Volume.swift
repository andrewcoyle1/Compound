//
//  MethodInfo+Volume.swift
//  Compound
//
//  Weekly training volume: what counts as a hard set, the tiers every muscle is read against,
//  planned sets on a template, and the per-muscle volume suggestion.
//

import Foundation

// Each summary is one localized sentence group, kept on one line so it extracts as one string.
// swiftlint:disable line_length
extension MethodInfo {
    static var allVolume: [MethodInfo] {
        [weeklyHardSets, weeklyVolumeTiers, plannedSetsPerMuscle, volumeRecommendation]
    }

    static let weeklyHardSets = MethodInfo(
        id: "volume.hardSets",
        title: "Weekly Hard Sets",
        summary: "Sets per muscle count only hard sets: finished, not warm-ups, and not logged below RPE 6. A set with no RPE still counts, so not logging effort costs you nothing. An exercise's main muscles get the whole set and the muscles it only assists get half. A left and right set count as one. Each finished drop, or mini-set of a myo-rep or rest-pause set, adds half a set, up to two sets in all. Weeks are rolling seven-day windows.",
        formula: """
        hard set = completed AND not warm-up AND (RPE missing OR RPE ≥ 6)
        set credit = min(2, 1 + 0.5 × finished drops or myo/rest-pause mini-sets)
        muscle sets = Σ set credit × (1 if primary, 0.5 if secondary)
        left + right pair = one set, worth its better half
        """,
        limitations: "The half-set credit is the best-supported way to count, but which muscles an exercise lists as assisting is a judgment, and the credit is the same for every exercise. Sets are not weighted by load or reps, and RPE is self-reported.",
        ownChoices: "The RPE 6 cut-off (about four reps in reserve), the half-set credit per drop or mini-set and the cap of two sets are Compound's own choices. The research shows only that sets nearer failure build more muscle, not where a set stops counting.",
        citations: [.pelland2026, .robinson2024, .refalo2023, .schoenfeld2021, .schoenfeld2017b]
    )

    static let weeklyVolumeTiers = MethodInfo(
        id: "volume.tiers",
        title: "Weekly Volume Tiers",
        summary: "Every muscle is read against the same tiers of weekly hard sets: below maintenance (fewer than 4), maintaining (4 to under 10), productive (10–20) and high (over 20). Muscle growth keeps rising with weekly sets, with smaller gains for each extra set and no clear plateau below about 20. No meta-analysis supports a lower target for small muscles, and the one muscle-level signal, for triceps, pointed the other way. Strength levels off at far fewer sets than size.",
        formula: """
        < 4 sets/week    below maintenance
        4 to < 10        maintaining
        10–20            productive
        > 20             high
        """,
        limitations: "The tiers come from group averages, mostly in young adults. People respond differently, and above 20 sets can still be right for someone who keeps progressing and recovering.",
        ownChoices: "The tier names and the 4 and 10 cut-points are Compound's own choices. The 4-set line is anchored loosely on the minimal dose found to maintain strength. Only the 10–20 band rests on the meta-analyses.",
        citations: [.pelland2026, .schoenfeld2017, .bazvalle2022, .spiering2021, .pelland]
    )

    static let plannedSetsPerMuscle = MethodInfo(
        id: "volume.plannedSets",
        title: "Planned Sets per Muscle",
        summary: "A template's target sets per muscle add up its planned sets the way logged sets are counted: the whole set for an exercise's main muscles, half a set for the muscles it only assists. Drops and mini-sets are credited once they are logged, not in the plan.",
        formula: "planned sets = Σ planned sets × (1 if primary, 0.5 if secondary)",
        limitations: "A plan assumes every set will be hard; a set later logged below RPE 6 will not count towards the week.",
        citations: [.pelland2026]
    )

    static let volumeRecommendation = MethodInfo(
        id: "volume.recommendation",
        title: "Adjusts Based on Your Progress",
        summary: "A suggestion for this muscle's weekly hard sets over the next two to three weeks. It starts from your median weekly sets over the last four weeks and looks at three things: how the estimated one-rep max is moving on exercises that train this muscle directly, whether RPE is rising at the same load, and how many of your planned sets you did. If you did fewer than 80% of them, it suggests consistency first. If strength is rising, keep what you are doing. If it is flat with steady effort, add 10–20%. If it is falling, or effort is rising at the same load, take 20–33% off. Nothing changes in your templates unless you change them.",
        formula: """
        baseline = median weekly hard sets, last 4 weeks
          (fewer than 4 trained weeks: clamped into 10–20)
        trend = median over primary exercises of
                least-squares slope of e1RM ÷ mean e1RM × 7 × 100  (%/week)
        adherence < 80%                  → be consistent first
        trend < −0.5 OR RPE drift ≥ +1   → reduce 20–33%
        trend > +0.5                     → keep
        otherwise                        → add max(10%, 1 set) to 20%
        floor 4 sets (6 from age 60); suggestions rounded to whole sets
        """,
        limitations: "No closed-loop volume rule has been tested in a trial, so this is defensible in direction only. Session-to-session swings in estimated one-rep max can hide a real trend over four weeks, and sleep, stress and soreness are not taken into account.",
        ownChoices: "Every threshold is Compound's own: the four-week window, the ±0.5% a week flat band (a placeholder until it can be tuned on real training logs), the 80% adherence line, the RPE drift of 1, the 20–33% reduction, and the median across exercises. The 10–20% step follows trials of increases over habitual volume, and the 4-set floor follows the minimal maintenance dose.",
        citations: [.scarpelli2022, .camargo2026, .spiering2021, .pelland2026]
    )
}
// swiftlint:enable line_length
