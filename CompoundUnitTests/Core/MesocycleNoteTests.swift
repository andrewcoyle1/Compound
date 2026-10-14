//
//  MesocycleNoteTests.swift
//  CompoundUnitTests
//
//  An exercise's three notes from the tracker: this workout's, the exercise's own, and its
//  mesocycle note, written back to that slot of that day plan.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

@MainActor
struct MesocycleNoteTests {

    private func day(_ id: String, slot: String, notes: String?) -> WorkoutTemplateModel {
        WorkoutTemplateModel(
            id: id, authorId: "author-1", name: id,
            exercises: [WorkoutTemplateExercise(id: slot, exercise: .mock, setRestTimers: false, notes: notes)]
        )
    }

    private func mesocycle() -> Mesocycle {
        Mesocycle(
            id: "m1", authorId: "author-1", name: "Block", icon: "dumbbell", colour: "blue",
            workoutTemplates: [day("push", slot: "push-bench", notes: "Pause at the chest"), day("pull", slot: "pull-bench", notes: nil)]
        )
    }

    private struct Tracker {
        let presenter: WorkoutTrackerPresenter
        let interactor: WorkoutTrackerInteractorDouble
        let router: WorkoutTrackerRouterDouble
    }

    private func tracker(mesocycleId: String? = "m1") throws -> Tracker {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.mesocycles = [mesocycle()]
        interactor.activeSession = WorkoutSessionModel(authorId: "author-1", template: mesocycle().workoutTemplates[0], mesocycleId: mesocycleId)
        let router = WorkoutTrackerRouterDouble()
        let presenter = try WorkoutTrackerPresenter(interactor: interactor, router: router, saveRetryBackoff: .testImmediate)
        return Tracker(presenter: presenter, interactor: interactor, router: router)
    }

    @Test func theNoteGoesOnOneSlotOfOneDay() throws {
        let updated = try #require(mesocycle().settingNote("Elbows in", dayPlanId: "push", slotId: "push-bench"))
        #expect(updated.workoutTemplates[0].exercises[0].notes == "Elbows in")
        #expect(updated.workoutTemplates[1].exercises[0].notes == nil)
        #expect(mesocycle().settingNote("Elbows in", dayPlanId: "push", slotId: "pull-bench") == nil)
    }

    @Test func startingTheDayRemembersTheSlot() {
        let session = WorkoutSessionModel(authorId: "author-1", template: mesocycle().workoutTemplates[0], mesocycleId: "m1")
        #expect(session.exercises[0].planSlotId == "push-bench")
        #expect(session.exercises[0].planNotes == "Pause at the chest")
    }

    @Test func savingShowsAtOnceAndReachesTheMesocycle() async throws {
        let screen = try tracker()
        let presenter = screen.presenter, interactor = screen.interactor
        let exercise = presenter.workoutSession.exercises[0]
        #expect(presenter.canEditMesocycleNote(exercise))

        presenter.updateMesocycleNote(" Elbows in \n", exerciseId: exercise.id)

        #expect(presenter.workoutSession.exercises[0].planNotes == "Elbows in")
        #expect(await TestManagers.eventually { !interactor.savedMesocycles.isEmpty })
        #expect(interactor.savedMesocycles.first?.workoutTemplates[0].exercises[0].notes == "Elbows in")
    }

    @Test func aWorkoutOutsideAMesocycleHasNoMesocycleNote() throws {
        let presenter = try tracker(mesocycleId: nil).presenter
        #expect(!presenter.canEditMesocycleNote(presenter.workoutSession.exercises[0]))
    }

    @Test func aFailedSaveSaysSo() async throws {
        let screen = try tracker()
        let presenter = screen.presenter, interactor = screen.interactor, router = screen.router
        interactor.saveMesocycleError = URLError(.notConnectedToInternet)

        presenter.updateMesocycleNote("Elbows in", exerciseId: presenter.workoutSession.exercises[0].id)

        #expect(await TestManagers.eventually { router.alerts.contains("Unable to Save Note") })
        #expect(presenter.workoutSession.exercises[0].planNotes == "Elbows in")
    }
}

// MARK: - The note sheet

@MainActor
struct ExerciseNoteTabsTests {

    private typealias Interactor = ExerciseTrackerInteractorDouble

    private typealias Router = ExerciseTrackerRouterDouble

    private let exercise = WorkoutExerciseModel(
        id: "e1", authorId: "author-1", templateId: "bench", name: "Bench Press", trackingMode: .weightReps, index: 1,
        notes: "Felt strong", sets: [], planNotes: "Pause at the chest"
    )

    /// Each tab opens on the note already written, and Save writes only the ones that changed.
    @Test func saveWritesOnlyTheNotesThatChanged() async throws {
        let interactor = Interactor(), router = Router()
        interactor.notes["bench"] = "Bench at 30°"
        let presenter = ExerciseTrackerPresenter(interactor: interactor, router: router)
        var session: [String] = [], mesocycle: [String] = []

        presenter.onNotePressed(
            for: exercise, tab: .mesocycle, previousNote: nil,
            onSave: { session.append($0) }, onSaveMesocycleNote: { mesocycle.append($0) }
        )
        let delegate = try #require(router.delegates.first)
        #expect(delegate.tabs.map(\.kind) == [.session, .exercise, .mesocycle])
        #expect(delegate.selectedTab == .mesocycle)
        #expect(delegate.tabs.map { $0.text.wrappedValue } == ["Felt strong", "Bench at 30°", "Pause at the chest"])

        delegate.tabs[1].text.wrappedValue = "Bench at 45°"
        delegate.tabs[2].text.wrappedValue = ""
        delegate.onSave()

        #expect(session.isEmpty)
        #expect(mesocycle == [""])
        #expect(await TestManagers.eventually { interactor.savedNotes == ["Bench at 45°"] })
    }

    @Test func withoutAMesocycleThereIsNoMesocycleTab() throws {
        let router = Router()
        ExerciseTrackerPresenter(interactor: Interactor(), router: router)
            .onNotePressed(for: exercise, tab: .mesocycle, previousNote: nil, onSave: { _ in })
        let delegate = try #require(router.delegates.first)
        #expect(delegate.tabs.map(\.kind) == [.session, .exercise])
        #expect(delegate.selectedTab == .session)
    }
}
