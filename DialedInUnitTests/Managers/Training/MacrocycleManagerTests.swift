//
//  MacrocycleManagerTests.swift
//  DialedInUnitTests
//
//  A macrocycle runs its mesocycles in order: finishing one starts the next from a clean slate,
//  the last marks the macrocycle complete, and a repeat goes back to the first. Someone joining
//  part-way starts at the mesocycle and microcycle they are on.
//

import Testing
import Foundation
@testable import DialedIn

@MainActor
struct MacrocycleManagerTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func mesocycle(_ id: String, microcycles: Int = 1) -> Mesocycle {
        Mesocycle(
            id: id, authorId: "me", name: id, icon: "dumbbell", colour: "#FF0000", numMicrocycles: microcycles,
            workoutTemplates: [WorkoutTemplateModel(id: "\(id)-a", authorId: "me", name: "A", exercises: [WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)])],
            dateCreated: start
        )
    }

    private func finished(_ mesocycle: Mesocycle, at date: Date) -> WorkoutSessionModel {
        WorkoutSessionModel(
            authorId: "me", name: "A", workoutTemplateId: "\(mesocycle.id)-a", mesocycleId: mesocycle.id,
            dateCreated: date, endedAt: date, exercises: []
        )
    }

    @Test("Test Starting A Macrocycle Ends The One Before")
    func testStartingAMacrocycleEndsTheOneBefore() async throws {
        let manager = await TestManagers.signedInMacrocycleManager()
        let first = try await manager.startMacrocycle(authorId: "me", name: "First", mesocycleIds: ["meso-1"], startedAt: start)
        #expect(await TestManagers.eventually { manager.currentMacrocycle?.id == first.id })
        let second = try await manager.startMacrocycle(authorId: "me", name: "Second", mesocycleIds: ["meso-2"], startedAt: start.addingTimeInterval(60))

        #expect(await TestManagers.eventually { manager.currentMacrocycle?.id == second.id })
        #expect(await TestManagers.eventually { manager.macrocycles.first { $0.id == first.id }?.status == .ended })
    }

    @Test("Test A Saved Macrocycle That Was Never Started Is Not Followed")
    func testASavedMacrocycleThatWasNeverStartedIsNotFollowed() async throws {
        let saved = Macrocycle(authorId: "me", name: "Later", mesocycleIds: ["meso-1"], status: .notStarted)
        let manager = await TestManagers.signedInMacrocycleManager(macrocycles: [saved])

        #expect(manager.currentMacrocycle == nil)
    }

    @Test("Test The Current Mesocycle Schedules From Its Own Start")
    func testTheCurrentMesocycleSchedulesFromItsOwnStart() async throws {
        let manager = await TestManagers.signedInMacrocycleManager()
        let followed = mesocycle("meso-1")
        try await manager.startMacrocycle(authorId: "me", name: "Macro", mesocycleIds: [followed.id], startedAt: start.addingTimeInterval(3600))
        #expect(await TestManagers.eventually { manager.currentMacrocycle != nil })

        #expect(manager.run(for: followed, sessions: [])?.startedAt == start.addingTimeInterval(3600))
        #expect(manager.run(for: mesocycle("elsewhere"), sessions: [])?.startedAt == Date(timeIntervalSince1970: 0))
    }

    @Test("Test Starting Part-Way Picks The Mesocycle And Microcycle")
    func testStartingPartWayPicksTheMesocycleAndMicrocycle() async throws {
        let manager = await TestManagers.signedInMacrocycleManager()
        let second = mesocycle("meso-2", microcycles: 4)
        let saved = Macrocycle(authorId: "me", name: "Macro", mesocycleIds: ["meso-1", second.id], status: .notStarted)

        let started = try await manager.start(saved, atMesocycle: 1, microcycle: 2, now: start)
        #expect(started.status == .active)
        #expect(started.currentMesocycleId == second.id)
        #expect(started.startMicrocycleIndex == 2)
        #expect(started.iteration == 1)
        #expect(await TestManagers.eventually { manager.currentMacrocycle?.id == saved.id })

        let run = try #require(manager.run(for: second, sessions: []))
        let progress = MesocycleSchedule.progress(of: run, sessions: [])
        #expect(progress.currentCycleIndex == 2)
        #expect(progress.cycles[0][0].state == .beforeStart)
        #expect(progress.cycles[1][0].state == .beforeStart)
        #expect(progress.cycles[2][0].state == .open)
    }

    @Test("Test Moving To The Next Mesocycle Starts It From Its First Microcycle")
    func testMovingToTheNextMesocycleStartsFromItsFirstMicrocycle() async throws {
        let manager = await TestManagers.signedInMacrocycleManager()
        let first = mesocycle("meso-1", microcycles: 2)
        let saved = Macrocycle(authorId: "me", name: "Macro", mesocycleIds: [first.id, "meso-2"], status: .notStarted)
        let started = try await manager.start(saved, atMesocycle: 0, microcycle: 1, now: start)
        let progress = MesocycleSchedule.progress(
            of: MesocycleSchedule.Run(mesocycle: first, startedAt: start, firstMicrocycleIndex: 1),
            sessions: [finished(first, at: start.addingTimeInterval(60))]
        )

        let later = start.addingTimeInterval(120)
        let advanced = try #require(await manager.advanceIfMesocycleComplete(started, progress: progress, now: later))

        #expect(advanced.mesocycleIndex == 1)
        #expect(advanced.currentMesocycleId == "meso-2")
        #expect(advanced.mesocycleStartedAt == later)
        #expect(advanced.startMicrocycleIndex == nil)
        #expect(advanced.status == .active)
    }

    @Test("Test An Unfinished Mesocycle Does Not Move")
    func testAnUnfinishedMesocycleDoesNotMove() async throws {
        let manager = await TestManagers.signedInMacrocycleManager()
        let macrocycle = try await manager.startMacrocycle(authorId: "me", name: "Macro", mesocycleIds: ["meso-1", "meso-2"], startedAt: start)
        let progress = MesocycleSchedule.progress(of: MesocycleSchedule.Run(mesocycle: mesocycle("meso-1"), startedAt: start), sessions: [])

        #expect(try await manager.advanceIfMesocycleComplete(macrocycle, progress: progress) == nil)
    }

    @Test("Test Finishing The Last Mesocycle Completes The Macrocycle And Repeat Starts Over")
    func testFinishingTheLastMesocycleCompletesTheMacrocycle() async throws {
        let manager = await TestManagers.signedInMacrocycleManager()
        let only = mesocycle("meso-1")
        let macrocycle = try await manager.startMacrocycle(authorId: "me", name: "Macro", mesocycleIds: [only.id], startedAt: start)
        let progress = MesocycleSchedule.progress(of: MesocycleSchedule.Run(mesocycle: only, startedAt: start), sessions: [finished(only, at: start.addingTimeInterval(60))])

        let completed = try #require(await manager.advanceIfMesocycleComplete(macrocycle, progress: progress))
        #expect(completed.status == .completed)
        #expect(await TestManagers.eventually { manager.currentMacrocycle?.status == .completed })

        let later = start.addingTimeInterval(600)
        let repeated = try await manager.repeatMacrocycle(completed, now: later)
        #expect(repeated.status == .active)
        #expect(repeated.mesocycleIndex == 0)
        #expect(repeated.mesocycleStartedAt == later)
        #expect(repeated.iteration == 2)
        #expect(repeated.skips.isEmpty)
    }

    @Test("Test A Skip Is Recorded Against The Current Mesocycle")
    func testASkipIsRecordedAgainstTheCurrentMesocycle() async throws {
        let manager = await TestManagers.signedInMacrocycleManager()
        let only = mesocycle("meso-1")
        let macrocycle = try await manager.startMacrocycle(authorId: "me", name: "Macro", mesocycleIds: [only.id], startedAt: start)
        let slot = try #require(MesocycleSchedule.progress(of: MesocycleSchedule.Run(mesocycle: only, startedAt: start), sessions: []).next)

        let updated = try await manager.skip(slot, in: macrocycle)

        #expect(updated.currentSkips.map(\.templateId) == ["meso-1-a"])
        let run = MesocycleSchedule.Run(mesocycle: only, startedAt: start, skips: updated.currentSkips)
        #expect(MesocycleSchedule.progress(of: run, sessions: []).isMesocycleComplete)
    }

    @Test("Test Deleting A Macrocycle Removes It")
    func testDeletingAMacrocycleRemovesIt() async throws {
        let saved = Macrocycle(authorId: "me", name: "Later", mesocycleIds: ["meso-1"], status: .notStarted)
        let manager = await TestManagers.signedInMacrocycleManager(macrocycles: [saved])

        try await manager.delete(saved)

        #expect(await TestManagers.eventually { manager.macrocycles.isEmpty })
    }
}
