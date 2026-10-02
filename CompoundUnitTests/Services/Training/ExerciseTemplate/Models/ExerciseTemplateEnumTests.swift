//
//  ExerciseTemplateEnumTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 28/10/2025.
//

import Testing
import Foundation
@testable import Compound

/// The raw values of the enums an exercise is stored with.
///
/// These are not cosmetic: every one is written into Firestore and into local persistence as its
/// raw string, so renaming a case without a migration silently fails to decode every exercise
/// already saved with the old spelling. Pinning them here makes that a failing test rather than a
/// user's library coming back empty.
///
/// This file used to cover `ExerciseCategory` and `MuscleGroup`, which the exercise redesign
/// replaced: equipment moved to `EquipmentVariation`, what is measured to `TrackableExerciseMetric`,
/// the movement pattern to `ExerciseType`, and the seven coarse muscle groups to the 22 specific
/// `Muscles`.
@MainActor
struct ExerciseEnumRawValueTests {

    // MARK: - Muscles

    @Test("Test Muscles Raw Values")
    func testMusclesRawValues() {
        #expect(Muscles.triceps.rawValue == "triceps")
        #expect(Muscles.upperTraps.rawValue == "upperTraps")
        #expect(Muscles.obliques.rawValue == "obliques")
        #expect(Muscles.neck.rawValue == "neck")
        #expect(Muscles.lats.rawValue == "lats")
        #expect(Muscles.forearms.rawValue == "forearms")
        #expect(Muscles.sideDelts.rawValue == "sideDelts")
        #expect(Muscles.rearDelts.rawValue == "rearDelts")
        #expect(Muscles.frontDelts.rawValue == "frontDelts")
        #expect(Muscles.chest.rawValue == "chest")
        #expect(Muscles.biceps.rawValue == "biceps")
        #expect(Muscles.upperBack.rawValue == "upperBack")
        #expect(Muscles.lowerBack.rawValue == "lowerBack")
        #expect(Muscles.abs.rawValue == "abs")
        #expect(Muscles.serratus.rawValue == "serratus")
        #expect(Muscles.quads.rawValue == "quads")
        #expect(Muscles.hamstrings.rawValue == "hamstrings")
        #expect(Muscles.glutes.rawValue == "glutes")
        #expect(Muscles.calves.rawValue == "calves")
        #expect(Muscles.abductors.rawValue == "abductors")
        #expect(Muscles.adductors.rawValue == "adductors")
        #expect(Muscles.tibialis.rawValue == "tibialis")
    }

    /// A new muscle needs a raw value pinned above and a name below, so the count is what notices
    /// one being added.
    @Test("Test Every Muscle Is Accounted For")
    func testEveryMuscleIsAccountedFor() {
        #expect(Muscles.allCases.count == 22)
        #expect(Set(Muscles.allCases.map(\.rawValue)).count == 22)
    }

    @Test("Test Muscles Identify Themselves By Raw Value")
    func testMusclesIdentifyThemselvesByRawValue() {
        for muscle in Muscles.allCases {
            #expect(muscle.id == muscle.rawValue)
        }
    }

    @Test("Test Every Muscle Has A Name")
    func testEveryMuscleHasAName() {
        for muscle in Muscles.allCases {
            #expect(!muscle.name.isEmpty)
        }
        #expect(Muscles.upperTraps.name == "Upper Traps")
        #expect(Muscles.frontDelts.name == "Front Delts")
    }

    // MARK: - ExerciseType

    @Test("Test ExerciseType Raw Values")
    func testExerciseTypeRawValues() {
        #expect(ExerciseType.compoundUpper.rawValue == "compoundUpper")
        #expect(ExerciseType.compoundLower.rawValue == "compoundLower")
        #expect(ExerciseType.isolationUpper.rawValue == "isolationUpper")
        #expect(ExerciseType.isolationLower.rawValue == "isolationLower")
        #expect(ExerciseType.core.rawValue == "core")
    }

    @Test("Test Every ExerciseType Is Accounted For")
    func testEveryExerciseTypeIsAccountedFor() {
        #expect(ExerciseType.allCases.count == 5)
    }

    @Test("Test ExerciseType Names")
    func testExerciseTypeNames() {
        #expect(ExerciseType.compoundUpper.name == "Upper Compound")
        #expect(ExerciseType.compoundLower.name == "Lower Compound")
        #expect(ExerciseType.isolationUpper.name == "Upper Isolation")
        #expect(ExerciseType.isolationLower.name == "Lower Isolation")
        #expect(ExerciseType.core.name == "Core")
    }

    // MARK: - Laterality

    @Test("Test Laterality Raw Values")
    func testLateralityRawValues() {
        #expect(Laterality.bilateral.rawValue == "bilateral")
        #expect(Laterality.unilateral.rawValue == "unilateral")
        // Spelled with the doubled s it was stored with; correcting it would orphan saved exercises.
        #expect(Laterality.assymetrical.rawValue == "assymetrical")
        #expect(Laterality.unilateralBilateral.rawValue == "unilateralBilateral")
    }

    @Test("Test Every Laterality Is Accounted For")
    func testEveryLateralityIsAccountedFor() {
        #expect(Laterality.allCases.count == 4)
    }

    @Test("Test Every Laterality Explains Itself")
    func testEveryLateralityExplainsItself() {
        for laterality in Laterality.allCases {
            #expect(!laterality.name.isEmpty)
            #expect(laterality.description?.isEmpty == false)
        }
    }

    // MARK: - TrackableExerciseMetric

    @Test("Test TrackableExerciseMetric Raw Values")
    func testTrackableExerciseMetricRawValues() {
        #expect(TrackableExerciseMetric.reps.rawValue == "reps")
        #expect(TrackableExerciseMetric.repsPerSide.rawValue == "repsPerSide")
        #expect(TrackableExerciseMetric.weight.rawValue == "weight")
        #expect(TrackableExerciseMetric.weightPerSide.rawValue == "weightPerSide")
        #expect(TrackableExerciseMetric.weightPerSidePersistent.rawValue == "weightPerSidePersistent")
        #expect(TrackableExerciseMetric.weightPerSideAssistance.rawValue == "weightPerSideAssistance")
        #expect(TrackableExerciseMetric.duration.rawValue == "duration")
        #expect(TrackableExerciseMetric.durationPerSide.rawValue == "durationPerSide")
        #expect(TrackableExerciseMetric.distanceShort.rawValue == "distanceShort")
        #expect(TrackableExerciseMetric.distanceShortPerSide.rawValue == "distanceShortPerSide")
        #expect(TrackableExerciseMetric.distanceLong.rawValue == "distanceLong")
    }

    @Test("Test TrackableExerciseMetric Names")
    func testTrackableExerciseMetricNames() {
        #expect(TrackableExerciseMetric.reps.name == "Reps")
        #expect(TrackableExerciseMetric.weightPerSidePersistent.name == "Weight Per Side (Persistent)")
    }

    // MARK: - MuscleTargetType

    @Test("Test MuscleTargetType Raw Values")
    func testMuscleTargetTypeRawValues() {
        #expect(MuscleTargetType.primary.rawValue == "primary")
        #expect(MuscleTargetType.secondary.rawValue == "secondary")
    }
}
