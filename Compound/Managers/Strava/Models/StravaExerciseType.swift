//
//  StravaExerciseType.swift
//  Compound
//
//  Which of Strava's `exercise_type` values a Compound exercise is uploaded as. Strava draws its
//  muscle heat map from these, so a set it cannot place is a set the map never shows.
//
//  The values are from https://developers.strava.com/docs/uploads/ (Supported Exercises).
//

enum StravaExerciseType {

    /// The type for a logged exercise: its own line in the table for a built-in exercise, else the
    /// generic type for its first primary muscle. `nil` when neither is known — a custom exercise
    /// since deleted, or one with no primary muscle — and its sets are then left out rather than
    /// guessed onto the wrong muscles.
    static func forExercise(templateId: String, library: [ExerciseModel]) -> String? {
        if let type = systemExercises[templateId] { return type }
        guard let exercise = library.first(where: { $0.id == templateId }),
              // `allCases` order, not the dictionary's, so the same exercise always maps the same way.
              let muscle = Muscles.allCases.first(where: { exercise.muscleGroups[$0] == .primary }) else { return nil }
        return genericByMuscle[muscle]
    }

    /// One line per exercise in `PrebuiltExercises.json`. A test fails when an exercise is added
    /// there without one here.
    static let systemExercises: [String: String] = [
        "system-barbell-bench-press": "BARBELL_BENCH_PRESS",
        "system-barbell-incline-bench-press": "INCLINE_BARBELL_BENCH_PRESS",
        "system-barbell-romanian-deadlift": "BARBELL_ROMANIAN_DEADLIFT",
        "system-barbell-sumo-deadlift": "SUMO_DEADLIFT",
        "system-cable-bicep-curl-straight-bar": "CABLE_BICEPS_CURL",
        "system-cable-pushdown-straight-bar": "CABLE_TRICEPS_PUSHDOWN",
        "system-calf-press-leg-press": "MACHINE_CALF_PRESS",
        "system-chest-dip": "CHEST_DIP",
        "system-dumbbell-incline-fly": "INCLINE_DUMBBELL_FLYE",
        "system-dumbbell-bench-press": "DUMBBELL_BENCH_PRESS",
        "system-dumbbell-seated-shoulder-press": "SEATED_DUMBBELL_SHOULDER_PRESS",
        "system-ez-barbell-preacher-curl": "EZ_BAR_PREACHER_CURL",
        "system-hack-squat": "MACHINE_HACK_SQUAT",
        "system-lat-prayer-straight-bar": "STRAIGHT_ARM_PULLDOWN",
        "system-overhead-extension-straight-bar": "CABLE_OVERHEAD_TRICEPS_EXTENSION",
        "system-reverse-fly": "MACHINE_REAR_DELT_REVERSE_FLY",
        "system-seated-leg-extension": "MACHINE_LEG_EXTENSION",
        "system-standing-lateral-raise-cable": "CABLE_LATERAL_RAISE",
        "system-barbell-squat": "BARBELL_BACK_SQUAT",
        "system-bulgarian-split-squat": "DUMBBELL_BULGARIAN_SPLIT_SQUATS",
        "system-lying-leg-curl": "LEG_CURL_GENERIC",
        "system-seated-row": "SEATED_CABLE_ROW",
        "system-single-arm-row": "DUMBBELL_ROW",
        "system-t-bar-row": "T_BAR_ROW",
        "system-cable-neutral-grip-lat-pulldown": "NEUTRAL_GRIP_LAT_PULLDOWN",
        "system-cable-overhead-triceps-extension": "CABLE_OVERHEAD_TRICEPS_EXTENSION",
        "system-cable-standing-supinated-face-pull": "FACE_PULL",
        "system-lever-hip-thrust": "MACHINE_HIP_THRUST",
        "system-lever-incline-hammer-chest-press": "MACHINE_INCLINE_CHEST_PRESS",
        "system-lever-pec-deck-fly-chest": "PEC_DECK_BUTTERFLY",
        "system-lever-pendulum-squat": "PENDULUM_SQUAT",
        "system-weighted-hammer-grip-pull-up-on-dip": "NEUTRAL_GRIP_PULL_UP",
        "system-low-to-high-cable-fly": "LOW_CABLE_FLY_CROSSOVERS",
        "system-wide-grip-pull-up": "WIDE_PULL_UP",
        "system-deficit-pendlay-row": "BENT_OVER_BARBELL_ROW",
        "system-single-arm-bayesian-curl": "BAYESIAN_CURL",
        "system-smith-machine-back-squat": "SMITH_MACHINE_SQUAT",
        "system-seated-plate-loaded-machine-calf-raise": "SEATED_CALF_RAISE",
        "system-kneeling-cable-crunch": "CABLE_CRUNCH",
        "system-overhand-grip-plate-loaded-row": "MACHINE_CHEST_SUPPORTED_ROW",
        "system-single-arm-45-degree-cable-rear-delt-fly": "CABLE_REAR_DELT_FLY",
        "system-barbell-shrug": "BARBELL_SHRUG",
        "system-pin-loaded-machine-shoulder-press": "MACHINE_SEATED_SHOULDER_PRESS",
        "system-dumbbell-fly": "DUMBBELL_FLYE",
        // Strava's CABLE_KICKBACK is the glute kickback; this is the closest triceps one.
        "system-neutral-grip-cable-triceps-kickback": "DUMBBELL_KICKBACK",
        "system-captains-chair-knee-raise": "HANGING_KNEE_RAISE",
        "system-45-degree-leg-press": "MACHINE_LEG_PRESS",
        "system-seated-hamstring-curl": "MACHINE_LEG_CURL_SEATED",
        "system-seated-machine-hip-adduction": "MACHINE_HIP_ADDUCTION",
        "system-seated-machine-hip-abduction": "MACHINE_HIP_ABDUCTION",
        "system-45-degree-incline-dumbbell-press": "INCLINE_DUMBBELL_BENCH_PRESS",
        "system-wide-grip-cable-lat-pulldown": "LAT_PULLDOWN",
        "system-bent-over-barbell-row": "BENT_OVER_BARBELL_ROW",
        "system-smith-machine-front-foot-elevated-split-squat": "SMITH_MACHINE_LUNGE",
        "system-goblet-roman-chair-hip-hinge": "BACK_EXTENSION",
        "system-machine-crunch-with-overhead-handles": "AB_CRUNCH_MACHINE",
        "system-overhand-grip-cable-lat-pulldown": "LAT_PULLDOWN",
        "system-wide-grip-cable-row": "SEATED_CABLE_ROW",
        "system-pause-cable-shrug-in": "SHRUG_GENERIC",
        "system-cable-rope-hammer-curl": "CABLE_HAMMER_CURL",
        "system-dumbbell-concentration-curl": "CONCENTRATION_CURL",
        "system-ez-bar-skull-crusher": "SKULL_CRUSHER",
        "system-ab-wheel-rollout": "AB_WHEEL_ROLLOUT",
        "system-dumbbell-reverse-lunge": "DUMBBELL_REVERSE_LUNGE"
    ]

    /// A type that works each muscle, for exercises people create themselves. A test checks every
    /// muscle has one.
    static let genericByMuscle: [Muscles: String] = [
        .chest: "BENCH_PRESS_GENERIC",
        .triceps: "TRICEPS_EXTENSION_GENERIC",
        .biceps: "CURL_GENERIC",
        .forearms: "BARBELL_WRIST_CURL",
        .frontDelts: "SHOULDER_PRESS_GENERIC",
        .sideDelts: "LATERAL_RAISE_GENERIC",
        .rearDelts: "DUMBBELL_REAR_DELT_FLY",
        .lats: "PULL_UP_GENERIC",
        .upperBack: "ROW_GENERIC",
        .upperTraps: "SHRUG_GENERIC",
        .neck: "SHRUG_GENERIC",
        .serratus: "SERRATUS_SHRUG",
        .lowerBack: "HYPEREXTENSION_GENERIC",
        .abs: "CRUNCH",
        .obliques: "RUSSIAN_TWIST",
        .quads: "SQUAT_GENERIC",
        .hamstrings: "LEG_CURL_GENERIC",
        .glutes: "HIP_RAISE_GENERIC",
        .calves: "CALF_RAISE_GENERIC",
        .abductors: "MACHINE_HIP_ABDUCTION",
        .adductors: "MACHINE_HIP_ADDUCTION",
        .tibialis: "TIBIALIS_RAISE"
    ]
}
