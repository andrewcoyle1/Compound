//
//  RestDurationRules.swift
//  Compound
//
//  How long the rest after a set is, in one place.
//
//  Two callers need the same answer: `SetTrackerRowPresenter`, when the user logs a set on the
//  tracker, and `LiveActivityIntentHandler`, when they log it from the Live Activity instead. A
//  rest that differed between the two would be the same workout resting for two different lengths
//  depending on which button was pressed, so the decision lives here and both call it.
//
//  Pure: everything it needs is passed in, so it can be exercised without a presenter, an
//  interactor or a manager.
//

import Foundation

enum RestDurationRules {

    /// What the rules need to know about the exercise, resolved by the caller from whatever it
    /// has — an interactor on the tracker, the managers themselves in the intent handler.
    struct ExerciseContext {
        /// The rest set for this one exercise, if any.
        let restOverrideSeconds: Int?
        /// The exercise's type, as `WorkoutSettings.restDurationsByExerciseType` keys it.
        let exerciseTypeRawValue: String?

        init(restOverrideSeconds: Int?, exerciseTypeRawValue: String?) {
            self.restOverrideSeconds = restOverrideSeconds
            self.exerciseTypeRawValue = exerciseTypeRawValue
        }
    }

    /// The unscaled rest for this exercise, narrowest setting first: the rest set on this one
    /// exercise, then the one set for its whole type, then the global default.
    ///
    /// A zero-second override is treated as no override at all. Both screens that write it clear
    /// to `nil` on an empty picker, but a document written by an older build can still carry a
    /// literal zero, and resting for no time is not something a user can have meant.
    static func baseRestDuration(settings: WorkoutSettings, context: ExerciseContext) -> Int {
        if let exerciseDuration = context.restOverrideSeconds, exerciseDuration > 0 {
            return exerciseDuration
        }
        if let typeRawValue = context.exerciseTypeRawValue,
           let typeDuration = settings.restDurationsByExerciseType[typeRawValue] {
            return typeDuration
        }
        return settings.defaultRestDurationSeconds
    }

    /// How long to rest after this set, or `nil` when the settings say not to rest here at all.
    ///
    /// A rest set by hand on the set wins outright and unscaled: the user typed that number for
    /// that set and meant it. Everything else starts from the base above and is then scaled by
    /// where the set sits in the exercise, because the moments are not the same rest — warm-ups
    /// are a ramp with no rest between them and one scaled rest after the last, the gap between
    /// the two limbs of one set is the time it takes to swap hands, the gap after the last set is
    /// the walk to the next exercise, and the gap between sets is the one that actually needs to
    /// be long.
    static func restAfterCompleting(
        _ set: WorkoutSetModel,
        in exercise: WorkoutExerciseModel,
        settings: WorkoutSettings,
        context: ExerciseContext,
        customRestSeconds: Int? = nil
    ) -> Int? {
        if let customRestSeconds {
            return customRestSeconds
        }

        let base = baseRestDuration(settings: settings, context: context)

        if set.isWarmup {
            // Warm-ups run straight into each other: they are a ramp, not work. The one rest a
            // warm-up can earn is after the last one, before the first working set, and that is
            // what `warmUpRestScaling` sizes.
            guard isLastWarmup(set, in: exercise), settings.restAfterLastWarmUp else { return nil }
            return scale(base, by: settings.warmUpRestScaling)
        }

        // Before the last-set check, because the left half of a pair is never the last working
        // set and would otherwise fall through to the full between-sets rest.
        if hasFollowingSidePartner(set, in: exercise) {
            guard settings.restBetweenSideSets else { return nil }
            return scale(base, by: settings.sideSetRestScaling)
        }

        if isLastWorkingSet(set, in: exercise) {
            guard settings.restBetweenExercises else { return nil }
            return scale(base, by: settings.betweenExercisesRestScaling)
        }

        return base
    }

    /// Scaling to nothing means no rest rather than a zero-second one.
    private static func scale(_ base: Int, by factor: Double) -> Int? {
        let scaled = Int((Double(base) * factor).rounded())
        return scaled > 0 ? scaled : nil
    }

    /// True when this set is the first limb of a pair whose other limb is still to come, so what
    /// follows is a swap of hands rather than a rest between sets.
    private static func hasFollowingSidePartner(_ set: WorkoutSetModel, in exercise: WorkoutExerciseModel) -> Bool {
        set.side == .left && exercise.sets.pairedSetIds(for: set.id).count == 2
    }

    private static func isLastWarmup(_ set: WorkoutSetModel, in exercise: WorkoutExerciseModel) -> Bool {
        exercise.sets.last(where: { $0.isWarmup })?.id == set.id
    }

    /// Warm-ups are prepended, so the last working set is the last of the sets that are not one.
    private static func isLastWorkingSet(_ set: WorkoutSetModel, in exercise: WorkoutExerciseModel) -> Bool {
        exercise.sets.last(where: { !$0.isWarmup })?.id == set.id
    }
}
