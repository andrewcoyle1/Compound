//
//  MesocycleDayDetailTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// A mesocycle's day on the workout detail screen. It lives in the mesocycle, not the library, so
/// it is edited there and kept apart from it only as a copy the user asks for.
extension TrainingTemplateDetailPresenterTests {

    private func block(authorId: String = "user-1") -> Mesocycle {
        Mesocycle(id: "m1", authorId: authorId, name: "Block", icon: "flag", colour: "#FF0000",
                  workoutTemplates: [TrainingTabFixture.template("Push")])
    }

    /// A day is the mesocycle's whether the library opened it (the delegate carries the
    /// mesocycle) or the mesocycle did (`mesocycleId`). A library template, or someone else's
    /// mesocycle, is not.
    @Test("Test A Day Is Recognised As Its Mesocycle's")
    func testADayIsRecognisedAsItsMesocycles() {
        let screen = makeScreen()
        screen.interactor.currentUser = UserModel(userId: "user-1")
        screen.interactor.mesocycles = [block()]
        let push = TrainingTabFixture.template("Push")

        let fromLibrary = WorkoutTemplateDetailDelegate(workoutTemplate: push, mesocycleId: nil, onStartWorkoutPressed: nil, mesocycle: block())
        let fromMesocycle = WorkoutTemplateDetailDelegate(workoutTemplate: push, mesocycleId: "m1", onStartWorkoutPressed: nil)
        let template = WorkoutTemplateDetailDelegate(workoutTemplate: push, mesocycleId: nil, onStartWorkoutPressed: nil)

        #expect(screen.presenter.owningMesocycle(delegate: fromLibrary)?.id == "m1")
        #expect(screen.presenter.owningMesocycle(delegate: fromMesocycle)?.id == "m1")
        #expect(screen.presenter.owningMesocycle(delegate: template) == nil)

        screen.interactor.mesocycles = [block(authorId: "someone-else")]
        #expect(screen.presenter.owningMesocycle(delegate: fromMesocycle) == nil)
    }

    @Test("Test Editing A Day Opens Its Mesocycle")
    func testEditingADayOpensItsMesocycle() {
        let screen = makeScreen()

        screen.presenter.onEditMesocyclePressed(block())

        #expect(screen.router.editedMesocycleIds == ["m1"])
        #expect(screen.router.createWorkoutDelegates.isEmpty)
    }

    /// The copy is a new workout, so it never shares an id with the day it came from, and it is
    /// named apart from a library workout of the same name.
    @Test("Test Saving A Copy Makes A Separate Workout")
    func testSavingACopyMakesASeparateWorkout() async {
        let screen = makeScreen()
        screen.interactor.currentUser = UserModel(userId: "user-1")
        screen.interactor.allWorkoutTemplates = [WorkoutTemplateModel(id: "lib-1", authorId: "user-1", name: "push")]
        let day = TrainingTabFixture.template("Push")

        screen.presenter.onSaveCopyPressed(template: day)

        #expect(await TestManagers.eventually { !screen.interactor.savedTemplates.isEmpty })
        let copy = screen.interactor.savedTemplates[0]
        #expect(copy.id != day.id)
        #expect(copy.authorId == "user-1")
        #expect(copy.name == "Push (copy)")
        #expect(screen.interactor.shownToasts.count == 1)
    }
}
