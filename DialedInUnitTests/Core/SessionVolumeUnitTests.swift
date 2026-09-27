//
//  SessionVolumeUnitTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

/// A workout's total volume sums exercises logged in different units. It used to be labelled kg
/// whatever the user used; it is now shown in the user's body-weight unit. Sets are stored in
/// kilograms, so the total is the kilogram sum converted once.
///
/// The session: 100 kg × 10 on one exercise and 225 lb × 5 on another, which is 1,000 kg +
/// 510.29 kg = 1,510.3 kg, or 2,204.62 lb + 1,125 lb = 3,329.6 lb.
@MainActor
struct SessionVolumeUnitTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private var exercises: [WorkoutExerciseModel] {
        [
            exercise(id: "kg", sets: [set("a", reps: 10, weightKg: 100)]),
            exercise(id: "lb", sets: [set("b", reps: 5, weightKg: UnitConversion.lbsToKg(225))])
        ]
    }

    private func set(_ id: String, reps: Int, weightKg: Double) -> WorkoutSetModel {
        WorkoutSetModel(id: id, authorId: "author-1", index: 1, reps: reps, weightKg: weightKg, isWarmup: false, completedAt: start, dateCreated: start)
    }

    private func exercise(id: String, sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
        WorkoutExerciseModel(id: id, authorId: "author-1", templateId: "template-\(id)", name: id, trackingMode: .weightReps, index: 1, sets: sets)
    }

    private func user(_ unit: WeightUnitPreference) -> UserModel {
        UserModel(userId: "author-1", submittedWeightUnitPreference: unit)
    }

    @Test(arguments: [(WeightUnitPreference.pounds, "3,329.6 lb"), (.kilograms, "1,510.3 kg")])
    func sessionDetailShowsVolumeInTheUsersUnit(unit: WeightUnitPreference, expected: String) {
        let interactor = WorkoutSessionDetailPresenterTests.Interactor()
        interactor.currentUser = user(unit)
        let presenter = WorkoutSessionDetailPresenter(interactor: interactor, router: WorkoutSessionDetailPresenterTests.Router())
        let session = WorkoutSessionModel(id: "s", authorId: "author-1", name: "Push", dateCreated: start, exercises: exercises)

        #expect(presenter.volumeFormatted(session: session) == expected)
    }

    @Test(arguments: [(WeightUnitPreference.pounds, "3,329.6 lb"), (.kilograms, "1,510.3 kg")])
    func trackerShowsVolumeInTheUsersUnit(unit: WeightUnitPreference, expected: String) throws {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.currentUser = user(unit)
        interactor.activeSession = WorkoutSessionModel(id: "s", authorId: "author-1", name: "Push", dateCreated: start, exercises: exercises)
        let presenter = try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble(), saveRetryBackoff: .testImmediate)

        #expect(presenter.formattedVolume == expected)
    }
}
