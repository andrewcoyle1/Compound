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
        /// The rest the plan sets on this exercise in this workout (`WorkoutExerciseModel.restSeconds`).
        let planRestSeconds: Int?

        init(restOverrideSeconds: Int?, exerciseTypeRawValue: String?, planRestSeconds: Int? = nil) {
            self.restOverrideSeconds = restOverrideSeconds
            self.exerciseTypeRawValue = exerciseTypeRawValue
            self.planRestSeconds = planRestSeconds
        }
    }

    /// The unscaled rest for this exercise, narrowest setting first: the plan's rest on this
    /// exercise in this workout, then the rest set on the exercise everywhere, then the one the
    /// user set for its whole type, then the type's default (`defaultSeconds(for:reps:)`), then
    /// the global default for an exercise with no type.
    ///
    /// A zero-second rest from the plan or override is treated as none at all. Both screens that
    /// write the override clear to `nil` on an empty picker, but a document written by an older
    /// build can still carry a literal zero, and resting for no time is not something a user can
    /// have meant.
    ///
    /// `reps` are the reps of the set just done, which separate heavy compound work from the rest.
    static func baseRestDuration(settings: WorkoutSettings, context: ExerciseContext, reps: Int? = nil) -> Int {
        if let planDuration = context.planRestSeconds, planDuration > 0 {
            return planDuration
        }
        if let exerciseDuration = context.restOverrideSeconds, exerciseDuration > 0 {
            return exerciseDuration
        }
        if let typeRawValue = context.exerciseTypeRawValue,
           let typeDuration = settings.restDurationsByExerciseType[typeRawValue] {
            return typeDuration
        }
        if let type = context.exerciseTypeRawValue.flatMap(ExerciseType.init(rawValue:)) {
            return defaultSeconds(for: type, reps: reps)
        }
        return settings.defaultRestDurationSeconds
    }

    /// The rest a type gets until the user sets their own, after ACSM's 2–3 minutes for heavy
    /// multi-joint lifts and 1–2 minutes for assistance work (ACSM 2009), and the small, uncertain
    /// hypertrophy benefit of resting beyond about 90 s (Singer 2024):
    ///
    /// - multi-joint work of 6 reps or fewer: 180 s; other multi-joint work: 120 s;
    /// - isolation: 90 s; core: 60 s.
    ///
    /// With the reps unknown, multi-joint work gets 120 s. Sources and Compound's own choices:
    /// `MethodInfo.restIntervals`.
    static func defaultSeconds(for type: ExerciseType, reps: Int?) -> Int {
        switch type {
        case .compoundUpper, .compoundLower:
            if let reps, reps > 0, reps <= heavyRepCeiling { return 180 }
            return 120
        case .isolationUpper, .isolationLower:
            return 90
        case .core:
            return 60
        }
    }

    /// Sets of this many reps or fewer on a multi-joint lift count as heavy.
    static let heavyRepCeiling = 6

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

        // The reps of the working set (its parent's, for a drop) decide heavy from moderate. A
        // warm-up's few reps are not heavy work.
        let parentReps = set.parentSetId.flatMap { parentId in exercise.sets.first { $0.id == parentId } }?.reps
        let base = baseRestDuration(settings: settings, context: context, reps: set.isWarmup ? nil : parentReps ?? set.reps)

        if set.isWarmup {
            // Warm-ups run straight into each other: they are a ramp, not work. The one rest a
            // warm-up can earn is after the last one, before the first working set, and that is
            // what `warmUpRestScaling` sizes.
            guard isLastWarmup(set, in: exercise), settings.restAfterLastWarmUp else { return nil }
            return scale(base, by: settings.warmUpRestScaling)
        }

        // A drop or mini-set still to come belongs to this set: no rest before a drop, the short
        // intra-set rest before a mini-set or cluster. The set's last row then rests as the set
        // itself would have, so a drop on the last set still walks to the next exercise.
        if let next = followingSubSet(of: set, in: exercise) {
            return intraSetRest(before: next, in: exercise, settings: settings)
        }
        let parentId = set.parentSetId
        let set = exercise.sets.first { $0.id == parentId } ?? set

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

    /// How long to rest after this set, knowing the whole workout. On top of the rules above:
    ///
    /// - The workout's last open set rests not at all, a rest set by hand included: Finish comes
    ///   next, and a rest would only stand in front of it.
    /// - In a superset (members sharing `supersetGroupId`), a set whose partner still has a set
    ///   this round is a walk to the partner: `supersetTransitionRestSeconds`, none by default.
    ///   The round's last set rests the base rest, and the block's last set the between-exercises
    ///   rest. Warm-ups and the first limb of a pair keep their own rules.
    ///
    /// `workout` may hold `set` logged or not; it is read as logged.
    static func restAfterCompleting(
        _ set: WorkoutSetModel,
        in exercise: WorkoutExerciseModel,
        workout: [WorkoutExerciseModel],
        settings: WorkoutSettings,
        context: ExerciseContext,
        customRestSeconds: Int? = nil
    ) -> Int? {
        let isOpen = { (candidate: WorkoutSetModel) in candidate.completedAt == nil && candidate.id != set.id }
        guard workout.contains(where: { $0.sets.contains(where: isOpen) }) else { return nil }

        let single = restAfterCompleting(set, in: exercise, settings: settings, context: context, customRestSeconds: customRestSeconds)
        guard customRestSeconds == nil, let group = exercise.supersetGroupId, !set.isWarmup,
              !hasFollowingSidePartner(set, in: exercise),
              followingSubSet(of: set, in: exercise) == nil else { return single }
        let partners = workout.filter { $0.supersetGroupId == group && $0.id != exercise.id }
        guard !partners.isEmpty else { return single }

        let round = exercise.workingSetNumber(for: set)
        let partnerHasSetThisRound = partners.contains { partner in
            partner.sets.contains { !$0.isWarmup && isOpen($0) && partner.workingSetNumber(for: $0) <= round }
        }
        if partnerHasSetThisRound {
            return settings.supersetTransitionRestSeconds.flatMap { $0 > 0 ? $0 : nil }
        }

        let blockHasMore = ([exercise] + partners).contains { $0.sets.contains(where: isOpen) }
        let base = baseRestDuration(settings: settings, context: context, reps: set.reps)
        if blockHasMore {
            return base
        }
        guard settings.restBetweenExercises else { return nil }
        return scale(base, by: settings.betweenExercisesRestScaling)
    }

    /// Scaling to nothing means no rest rather than a zero-second one.
    private static func scale(_ base: Int, by factor: Double) -> Int? {
        let scaled = Int((Double(base) * factor).rounded())
        return scaled > 0 ? scaled : nil
    }

    /// The next drop, mini-set or cluster of the set `set` belongs to, after `set` itself.
    private static func followingSubSet(of set: WorkoutSetModel, in exercise: WorkoutExerciseModel) -> WorkoutSetModel? {
        let parentId = set.parentSetId ?? set.id
        guard let position = exercise.sets.firstIndex(where: { $0.id == set.id }) else { return nil }
        return exercise.sets[(position + 1)...].first { $0.parentSetId == parentId }
    }

    /// The rest before `subSet`, decided by its kind, or its parent's when the row itself is plain:
    /// each of myo-rep, rest-pause and cluster has its own (`WorkoutSettings.intraSetRest(for:)`).
    private static func intraSetRest(before subSet: WorkoutSetModel, in exercise: WorkoutExerciseModel, settings: WorkoutSettings) -> Int? {
        let parentKind = exercise.sets.first { $0.id == subSet.parentSetId }?.kind ?? .standard
        let kind = subSet.kind == .standard ? parentKind : subSet.kind
        guard let seconds = settings.intraSetRest(for: kind), seconds > 0 else { return nil }
        return seconds
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
    /// A drop or mini-set trailing it is part of it, not a set after it.
    private static func isLastWorkingSet(_ set: WorkoutSetModel, in exercise: WorkoutExerciseModel) -> Bool {
        exercise.sets.last(where: { !$0.isWarmup && !$0.isSubSet })?.id == set.id
    }
}
