//
//  WorkoutTrackerGymProfileTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The gym a workout is at. Its template names one; without that it is the favourite. Before
/// this, the tracker never loaded the template's gym and the rows always used the favourite.
@MainActor
struct WorkoutTrackerGymProfileTests {

    private let home = GymProfileModel(id: "gym-home", authorId: "author-1", name: "Home")

    private func makeScreen(
        templateGymId: String?,
        hasTemplate: Bool = true,
        favourite: GymProfileModel? = nil,
        router: WorkoutTrackerRouterDouble? = nil
    ) throws -> (WorkoutTrackerPresenter, WorkoutTrackerInteractorDouble) {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.favouriteGymProfile = favourite
        if hasTemplate {
            interactor.workoutTemplates["template-1"] = WorkoutTemplateModel(
                id: "template-1", authorId: "author-1", name: "Push", gymProfileId: templateGymId
            )
        }
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Push",
            workoutTemplateId: hasTemplate ? "template-1" : nil,
            dateCreated: Date(),
            exercises: []
        )
        return (try WorkoutTrackerPresenter(interactor: interactor, router: router ?? WorkoutTrackerRouterDouble()), interactor)
    }

    @Test("Test The Workout's Own Gym Wins Over The Favourite")
    func testWorkoutGymWins() async throws {
        let (presenter, interactor) = try makeScreen(templateGymId: "gym-work", favourite: home)

        await presenter.loadWorkoutGymProfile()

        #expect(interactor.workoutGymProfile?.id == "gym-work")
    }

    @Test("Test The Favourite Stands In When The Template Names No Gym")
    func testFavouriteWithoutTemplateGym() async throws {
        let (presenter, interactor) = try makeScreen(templateGymId: nil, favourite: home)

        await presenter.loadWorkoutGymProfile()

        #expect(interactor.activeWorkoutGymProfile == nil)
        #expect(interactor.workoutGymProfile?.id == "gym-home")
    }

    @Test("Test The Favourite Stands In For A Workout With No Template")
    func testFavouriteWithoutTemplate() async throws {
        let (presenter, interactor) = try makeScreen(templateGymId: nil, hasTemplate: false, favourite: home)

        await presenter.loadWorkoutGymProfile()

        #expect(interactor.workoutGymProfile?.id == "gym-home")
    }

    /// Gym Settings opens the gym the workout is at, which need not be a favourite.
    @Test("Test Gym Settings Opens The Workout's Gym")
    func testGymSettings() async throws {
        let router = WorkoutTrackerRouterDouble()
        let (presenter, _) = try makeScreen(templateGymId: "gym-work", router: router)
        presenter.onGymProfilePressed()
        #expect(router.shown.isEmpty)

        await presenter.loadWorkoutGymProfile()
        presenter.onGymProfilePressed()

        #expect(router.shown == ["gymProfile"])
    }

    /// The row's plates and steps come from the workout's gym, so a user with no favourite still
    /// gets them at the workout's gym.
    @Test("Test The Row Reads The Plates Of The Workout's Gym")
    func testRowReadsWorkoutGym() {
        let interactor = RowInteractor()
        let presenter = SetTrackerRowPresenter(interactor: interactor, router: RowRouter())
        let exercise = WorkoutExerciseModel(
            id: "e", authorId: "u", templateId: "t", name: "Squat", trackingMode: .weightReps, index: 0,
            sets: [WorkoutSetModel(id: "s", authorId: "u", index: 1, reps: 5, weightKg: 100, isWarmup: false, dateCreated: Date())],
            equipmentVariations: [EquipmentVariation(id: "v", resistanceEquipment: [EquipmentRef(kind: .loadableBar, id: "barbell")])]
        )

        #expect(presenter.plateSummary(exercise: exercise, set: exercise.sets[0]) == nil)

        interactor.workoutGymProfile = GymProfileModel(authorId: "u")
        #expect(presenter.plateSummary(exercise: exercise, set: exercise.sets[0]) != nil)
    }

    private final class RowInteractor: SpyGlobalInteractor, SetTrackerRowInteractor {
        var workoutSettings = WorkoutSettings(authorId: "u")
        var allExercises: [ExerciseModel] = []
        var favouriteGymProfile: GymProfileModel?
        var workoutGymProfile: GymProfileModel?
        func getPreference(templateId: String) -> ExerciseUnitPreference { ExerciseUnitPreference(exerciseModelId: templateId) }
        func exerciseRestOverride(for exerciseId: String) -> Int? { nil }
    }

    private final class RowRouter: SetTrackerRowRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showWarmupSetInfoModal(primaryButtonAction: @escaping () -> Void) { }
        func showRestModal(
            primaryButtonAction: @escaping () -> Void,
            secondaryButtonAction: @escaping () -> Void,
            minutesSelection: Binding<Int>,
            secondsSelection: Binding<Int>
        ) { }
    }
}
