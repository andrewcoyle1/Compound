//
//  TrainingSearchTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// Training's search field: exercises and workouts, and where a result goes.
@MainActor
struct TrainingSearchTests {

    private struct Screen {
        let presenter: TrainingPresenter
        let interactor: TrainingHomePresenterTests.Interactor
        let router: TrainingHomePresenterTests.Router
    }

    private func makeScreen() -> Screen {
        let interactor = TrainingHomePresenterTests.Interactor()
        let router = TrainingHomePresenterTests.Router()
        return Screen(presenter: TrainingPresenter(interactor: interactor, router: router), interactor: interactor, router: router)
    }

    /// Exercises match on name, alternate name or muscle; workouts on name or their exercises.
    /// Case and surrounding punctuation are ignored.
    @Test("Test Search Matches Exercises And Workouts")
    func testSearchMatchesExercisesAndWorkouts() {
        let screen = makeScreen()
        screen.interactor.allExercises = [
            trainingSearchExercise(id: "bench", name: "Bench Press", alternateNames: ["Flat Press"]),
            trainingSearchExercise(id: "squat", name: "Squat", muscles: [.quads: .primary])
        ]
        screen.interactor.allWorkoutTemplates = [TrainingTabFixture.template("Push Day")]

        #expect(screen.presenter.isSearching == false)

        screen.presenter.searchString = "flat press!"
        #expect(screen.presenter.filteredExercises.map(\.id) == ["bench"])

        screen.presenter.searchString = "QUADS"
        #expect(screen.presenter.filteredExercises.map(\.id) == ["squat"])

        screen.presenter.searchString = "push"
        #expect(screen.presenter.filteredWorkoutTemplates.map(\.name) == ["Push Day"])
        #expect(screen.presenter.hasSearchResults)

        screen.presenter.searchString = "zzz"
        #expect(screen.presenter.hasSearchResults == false)
    }

    @Test("Test A Workout Result Starts The Workout And Opens The Tracker")
    func testAWorkoutResultStartsTheWorkoutAndOpensTheTracker() async {
        let screen = makeScreen()

        screen.presenter.onStartWorkoutResultPressed(TrainingTabFixture.template("Push Day"))

        #expect(await TestManagers.eventually { screen.router.shown == ["tracker"] })
        #expect(screen.interactor.startedTemplateNames == ["Push Day"])
    }

    @Test("Test An Exercise Result Opens Its Detail")
    func testAnExerciseResultOpensItsDetail() {
        let screen = makeScreen()

        screen.presenter.onExerciseResultPressed(trainingSearchExercise(id: "squat", name: "Squat"))

        #expect(screen.router.shown == ["exerciseDetail:squat"])
    }

}

@MainActor
private func trainingSearchExercise(
    id: String,
    name: String,
    muscles: [Muscles: MuscleTargetType] = [.chest: .primary],
    alternateNames: [String] = []
) -> ExerciseModel {
    ExerciseModel(
        id: id,
        authorId: "user-1",
        name: name,
        trackableMetrics: [.weight, .reps],
        type: .compoundUpper,
        laterality: .bilateral,
        muscleGroups: muscles,
        isBodyweight: false,
        rangeOfMotion: 4,
        stability: 5,
        bodyWeightContribution: 0,
        alternateNames: alternateNames
    )
}
