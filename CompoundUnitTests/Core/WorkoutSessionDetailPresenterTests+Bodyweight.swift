//
//  WorkoutSessionDetailPresenterTests+Bodyweight.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// With the bodyweight contribution shown, the finish summary's volume is at effective load: the
/// external load plus the share of today's bodyweight the movement lifts.
extension WorkoutSessionDetailPresenterTests {

    private func dips(authorId: String = "author-1") -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "e1",
            authorId: authorId,
            templateId: "dip",
            name: "Dip",
            trackingMode: .weightReps,
            index: 1,
            sets: [
                WorkoutSetModel(id: "w", authorId: authorId, index: 1, reps: 8, weightKg: nil, isWarmup: true, dateCreated: start),
                WorkoutSetModel(id: "a", authorId: authorId, index: 2, reps: 8, weightKg: 20, isWarmup: false, dateCreated: start),
                WorkoutSetModel(id: "b", authorId: authorId, index: 3, reps: 10, weightKg: nil, isWarmup: false, dateCreated: start)
            ]
        )
    }

    private func bodyweightScreen(showsContribution: Bool) -> Screen {
        let screen = makeScreen()
        screen.interactor.allExercises = [ExerciseModel(
            id: "dip", authorId: "author-1", name: "Dip", trackableMetrics: [.weight, .reps], type: .compoundUpper,
            laterality: .bilateral, muscleGroups: [.triceps: .primary], isBodyweight: false, rangeOfMotion: 4, stability: 3,
            bodyWeightContribution: 100, alternateNames: []
        )]
        screen.interactor.currentWeightKilograms = 80
        screen.interactor.workoutSettings.showBodyweightContribution = showsContribution
        return screen
    }

    @Test("Test Volume Counts The Bodyweight Lifted With The Setting On")
    func testEffectiveVolume() {
        let screen = bodyweightScreen(showsContribution: true)
        let workout = session(exercises: [dips()])

        // (20 + 80) × 8 + 80 × 10; the warm-up stays out.
        #expect(screen.presenter.totalVolume(session: workout) == 1600)
        #expect(screen.presenter.exerciseSummary(dips()) == "2 sets · \(Format.weight(kg: 1600, unit: .kilograms)) volume")
    }

    @Test("Test Volume Is The External Load With The Setting Off")
    func testVolumeOff() {
        let screen = bodyweightScreen(showsContribution: false)

        #expect(screen.presenter.totalVolume(session: session(exercises: [dips()])) == 160)
    }

    /// The device knows only its own user's bodyweight, so a friend's workout is never scaled by it.
    @Test("Test Another Author's Volume Leaves Bodyweight Out")
    func testOtherAuthor() {
        let screen = bodyweightScreen(showsContribution: true)
        let workout = WorkoutSessionModel(id: "session-1", authorId: "friend", name: "Push Day", dateCreated: start, exercises: [dips(authorId: "friend")])

        #expect(screen.presenter.totalVolume(session: workout) == 160)
    }
}
