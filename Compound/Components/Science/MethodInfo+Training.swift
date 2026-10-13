//
//  MethodInfo+Training.swift
//  Compound
//
//  Strength training: the estimated one-rep max, smart progression, the mesocycle deload,
//  warm-up sets, rest timers and tonnage.
//

import Foundation

// Each summary is one localized sentence group, kept on one line so it extracts as one string.
// swiftlint:disable line_length
extension MethodInfo {
    static var allTraining: [MethodInfo] {
        [estimatedOneRepMax, smartProgression, mesocycleDeload, warmupSets, restIntervals, tonnage]
    }

    static let estimatedOneRepMax = MethodInfo(
        id: "training.e1rm",
        title: "Estimated One-Rep Max",
        summary: "Your one-rep max is estimated from each completed working set with Epley's equation, using the reps you could have done: the reps logged plus the reps you had left, read from the RPE you logged (RPE 8 means 2 left). With no RPE, only the reps you did count. A single taken to failure is its own max. Sets that come to more than 10 reps to failure give no estimate, because prediction equations agree closely at low reps and drift apart above about 10. Those sets still count for volume and rep records. Each session shows its best set's estimate. On a plate-loaded machine set to enter plates only, the weight is the plates you loaded, not the machine's own weight.",
        formula: """
        n = reps + (10 − RPE)   (RPE logged)
        n = reps                (no RPE)
        e1RM = weight                 if n ≤ 1
        e1RM = weight × (1 + n / 30)  if 1 < n ≤ 10
        no estimate                   if n > 10
        """,
        limitations: "This is an estimate, not a tested max, and it is less reliable as reps rise. No single equation is best for every lift or person: people trained for endurance do far more reps at a given share of their max than strength athletes. People also tend to underestimate their reps in reserve by about one rep, which makes the estimate slightly low, the cautious direction.",
        ownChoices: "Using Epley rather than another equation, and treating a set with no RPE as having no reps in reserve, are Compound's own choices. The 10-rep cap follows Reynolds et al. Showing it as an estimate rather than a tested max is a choice too: there is no published error band for it.",
        citations: [.reynolds2006, .epley1985, .zourdos2016, .halperin2022, .richens2014, .ribeiro2024]
    )

    static let smartProgression = MethodInfo(
        id: "training.smartProgression",
        title: "Smart Progression",
        summary: "Smart Progression uses double progression: it adds reps across your rep range at the same weight, then adds weight and returns to the bottom of the range. Weight goes on when most sets (weight-first) or every set (reps-first) reach the top of the range and no set was logged harder than its reps-in-reserve target. A failure set aims for none in reserve. Without a target, a compound set logged at RPE 10 doesn't earn weight. A set with no rep range is worked through 8–12, and reps under 8 there are not a miss; a range with only one end set reaches four reps to the other. If you don't log RPE, the top of the range has to be reached on two sessions in a row at that weight. The step is a share of the weight, rounded to your equipment: 5% for lower-body compounds, 2.5% for upper-body compounds and 5% for isolation and core work. It is never less than your smallest plate or pin. When even that step is more than 10% of the weight, as with 2 kg on a light dumbbell or 10 kg on a bar with no plates under 5 kg, you add a rep each session until your reps carry the heavier weight for the bottom of the range. With nothing heavier at all, at the top of a stack or a gap in the rack, you add a rep; body-weight work, and a set logged with no weight, does a rep more than last time. History comes from sessions done with the same kind of load, so dumbbell sets never set a barbell weight, and passes over deload weeks. Timed sets grow 10% (at least 5 seconds) and distances 5%. One session below the range repeats the weights. A second in a row, at the same weight and not stopped short (RPE 9.5 or above, or no RPE), resets the weight. The new weight is worked back from that set's estimated one-rep max to the bottom of the range with 2 reps in reserve, or with the template's target.",
        formula: """
        step = max(weight × p, smallest increment), rounded to equipment
          p = 5% lower compound, 2.5% upper compound or untyped, 5% isolation/core
        if step > 10% of weight and weight × (1 + reps/30) < (weight + step) × (1 + min/30):
          reps + 1 instead
        reset weight = e1RM ÷ (1 + (min reps + RIR target)/30)
          clamped to 85–95% of the weight missed; 90% when there is no estimate
        nothing heavier, no weight, or body weight → reps + 1
        no range → 8–12, and reps under 8 are not a miss
        time → max(round5(s × 1.1), s + 5); distance → max(round(m × 1.05), m + step)
          step = 1 m under 200 m, 10 m under 2 km, else 50 m
        live: missed by 2+ → 5% lighter, rounded down; beat max by 2 at RPE ≤ 8 → + step
          only sets asked for the same as the one logged; drops and pieces are left alone
        """,
        limitations: "No trial has compared percentage steps with fixed ones. The rep fallback rests on a trial in which adding reps and adding load built muscle equally. RPE-based loading did at least as well as percentage-based loading, and hypertrophy improves closer to failure while strength responds more to load. RPE is self-reported and tends to underestimate the reps left.",
        ownChoices: "The step percentages (chosen within the 2–10% range ACSM describes), the 10% limit, the 1-rep-in-reserve default for compounds, the two-session rule without RPE, the RPE 9.5 reset trigger, the 2 reps in reserve and 5–15% limits of a reset, the in-session 5% cut, the 8–12 default range, the time and distance steps and reading history by kind of load are Compound's own choices. The 10% fallback is the practitioner convention it replaces. The rep fallback uses Epley's equation past 10 reps, which the one-rep max does not: it compares two weights at the same reps rather than estimating a max, which is where the equation holds up best.",
        citations: [.acsm2009, .plotkin2022, .helms2018, .robinson2024, .epley1985, .zourdos2016, .halperin2022, .rippetoe2011, .wendler2009]
    )

    static let mesocycleDeload = MethodInfo(
        id: "training.deload",
        title: "Deload Week",
        summary: "In a mesocycle's deload week, each exercise keeps about half its working sets (half, rounded up, so 4 becomes 2 and 3 becomes 2) at 90% of the planned weight, rounded down to your equipment, and a step lighter where 90% would round back to the planned weight. Reps stay as planned and warm-ups stay. The week after a deload carries on from the week before it. You keep training as often as usual. Lifters and coaches deload mostly by cutting volume and effort while keeping frequency. In a survey of strength and physique athletes, a typical deload lasted about a week every 5 to 6 weeks.",
        formula: """
        sets kept = max(1, ⌈planned working sets × 0.5⌉)
        weight = planned weight × 0.90, rounded down to equipment
        assistance = planned assistance × 1.10
        progression afterwards reads past the deload week
        """,
        limitations: "Deloading is widely practised but little studied. The one trial found that a full week off mid-programme did not change muscle growth and slightly reduced strength gains, so the benefit is mainly recovery and practicality.",
        ownChoices: "Half the sets, 90% of the weight (the middle of 85–95%), and keeping warm-ups are Compound's own choices. When the deload falls is set by the mesocycle.",
        citations: [.bell2023, .rogerson2024, .bell2022, .coleman2024]
    )

    static let warmupSets = MethodInfo(
        id: "training.warmups",
        title: "Warm-Up Sets",
        summary: "Warm-up sets are lighter sets before your working sets that prepare your muscles and joints. They don't count toward volume or personal records. Compound ramps them up to the working weight with fewer reps as the load rises, so the last warm-up primes the working weight without becoming an extra working set: 8 reps up to half the weight, 5 up to 70%, 3 up to 85% and 2 above. Heavy compound work of 6 reps or fewer gets 3 warm-ups at about 45, 65 and 82%. Work of 7–12 reps gets 2 at 50 and 75%. Lighter work, isolation and core exercises get 1 at 60%. Work at bodyweight or with assistance gets none, as there is no lighter load to ramp through. A warm-up count set in the plan always wins, and its assisted warm-ups get more assistance than the work.",
        formula: """
        count: isolation/core 1; compound reps ≤ 6 → 3, 7–12 → 2, > 12 → 1, unknown → 2
        loads: 1 → 60%; 2 → 50, 75%; 3 → 45, 65, 82%; 4+ → 45, 60, 75, 85, 90…%
        reps: ≤ 50% → 8, ≤ 70% → 5, ≤ 85% → 3, above → 2
        no plan count: a warm-up rounded up to the working weight is dropped
        no plan count and no load (bodyweight, assistance): no warm-ups
        assisted, planned: assistance × (2 − share)
        """,
        limitations: "Studies found that a warm-up at higher loads with few reps, such as 6 reps at 40% then 80% of the training load, made the first working sets faster than lighter or no warm-ups. They tested squat and bench press in trained people, not every exercise.",
        ownChoices: "The exact percentages, reps and counts, and using working reps as a stand-in for how heavy the work is, are Compound's own choices around the 40% and 80% anchors of the studies.",
        citations: [.ribeiro2020, .ribeiro2021]
    )

    static let restIntervals = MethodInfo(
        id: "training.rest",
        title: "Rest Timers",
        summary: "Until you set a time, the rest after a set depends on the exercise type: 3 minutes after compound sets of 6 reps or fewer, 2 minutes after other compound sets, 90 seconds after isolation sets and 60 seconds after core work. A time set in the plan, on the exercise or for its whole type takes priority, and so does a rest typed on the set. Longer rests help heavy multi-joint lifts keep their reps across sets. For muscle growth, the benefit of resting longer than about 60–90 seconds is small and uncertain.",
        formula: """
        compound, reps ≤ 6 → 180 s; compound otherwise → 120 s
        isolation → 90 s; core → 60 s; no type → your default (90 s)
        """,
        limitations: "The guidance comes mostly from studies of trained young adults. The best rest also depends on how you feel and how much time you have.",
        ownChoices: "The 6-rep cut-off and the exact times, chosen within ACSM's 2–3 minutes for heavy core lifts and 1–2 minutes for assistance work, are Compound's own choices. The 60-second core rest is too.",
        citations: [.acsm2009, .singer2024]
    )

    static let tonnage = MethodInfo(
        id: "training.tonnage",
        title: "Volume (Tonnage)",
        summary: "Volume is weight × reps summed over the working sets you logged. A dumbbell set is logged as one dumbbell, as it reads on the rack, so an exercise that holds one in each hand counts it twice; so does a left-and-right set logged as one. With Show Bodyweight Contribution on, your own workouts also count the share of your bodyweight a movement lifts, set on each exercise. Dips count 100%, pull-ups 95% and squats 85%. Force-plate studies put a push-up at about 64–75% of body mass and a knee push-up at about 49–62%. Assistance is taken off. Without it, or for other people's workouts, only the external load counts, so a pull-up adds nothing. The Progress tab's records and circle leaderboards always use external load, so they compare like with like. On a plate-loaded machine set to enter plates only, the weight is the plates you loaded, not the machine's own weight.",
        formula: """
        volume = Σ (external load × weights held + bodyweight × share − assistance) × reps × sides
        bodyweight share = exercise's bodyweight contribution (setting on, your own workouts)
        """,
        limitations: "Tonnage is a rough measure of work: it treats a heavy triple and a light set of fifteen alike, and it uses today's bodyweight, so older workouts change with the scale.",
        ownChoices: "The bodyweight shares in the exercise library (dips 100%, pull-ups 95%, squats and lunges 85%, hinges 60%) and the 75% starting value for a new bodyweight exercise are Compound's own choices. Only the push-up figures are measured.",
        citations: [.ebben2011, .suprak2011]
    )
}
// swiftlint:enable line_length
