//
//  TrainingPlanManagerTests.swift
//  DialedInUnitTests
//
//  A plan runs its blocks in order: finishing a block starts the next from a clean slate, the
//  last one marks the plan complete, and a repeat goes back to the first block with a new start.
//

import Testing
import Foundation
@testable import DialedIn

@MainActor
struct TrainingPlanManagerTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func program(_ id: String) -> TrainingProgram {
        TrainingProgram(
            id: id, authorId: "me", name: id, icon: "dumbbell", colour: "#FF0000", numMicrocycles: 1,
            workoutTemplates: [WorkoutTemplateModel(id: "\(id)-a", authorId: "me", name: "A", exercises: [WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)])],
            dateCreated: start
        )
    }

    private func finished(_ program: TrainingProgram, at date: Date) -> WorkoutSessionModel {
        WorkoutSessionModel(
            authorId: "me", name: "A", workoutTemplateId: "\(program.id)-a", trainingProgramId: program.id,
            dateCreated: date, endedAt: date, exercises: []
        )
    }

    @Test("Test Starting A Plan Ends The One Before")
    func testStartingAPlanEndsTheOneBefore() async throws {
        let manager = await TestManagers.signedInTrainingPlanManager()
        let first = try await manager.startPlan(authorId: "me", name: "First", programIds: ["block-1"], startedAt: start)
        #expect(await TestManagers.eventually { manager.currentPlan?.id == first.id })
        let second = try await manager.startPlan(authorId: "me", name: "Second", programIds: ["block-2"], startedAt: start.addingTimeInterval(60))

        #expect(await TestManagers.eventually { manager.currentPlan?.id == second.id })
        #expect(await TestManagers.eventually { manager.trainingPlans.first { $0.id == first.id }?.status == .ended })
    }

    @Test("Test The Current Block Schedules From Its Own Start")
    func testTheCurrentBlockSchedulesFromItsOwnStart() async throws {
        let manager = await TestManagers.signedInTrainingPlanManager()
        let block = program("block-1")
        try await manager.startPlan(authorId: "me", name: "Plan", programIds: [block.id], startedAt: start.addingTimeInterval(3600))
        #expect(await TestManagers.eventually { manager.currentPlan != nil })

        #expect(manager.run(for: block)?.startedAt == start.addingTimeInterval(3600))
        #expect(manager.run(for: program("elsewhere"))?.startedAt == start)
    }

    @Test("Test Finishing A Block Moves To The Next From A Clean Start")
    func testFinishingABlockMovesToTheNext() async throws {
        let manager = await TestManagers.signedInTrainingPlanManager()
        let block = program("block-1")
        let plan = try await manager.startPlan(authorId: "me", name: "Plan", programIds: ["block-1", "block-2"], startedAt: start)
        let progress = ProgramSchedule.progress(of: ProgramSchedule.Run(program: block, startedAt: start), sessions: [finished(block, at: start.addingTimeInterval(60))])

        let later = start.addingTimeInterval(120)
        let advanced = try #require(try await manager.advanceIfBlockComplete(plan, progress: progress, now: later))

        #expect(advanced.blockIndex == 1)
        #expect(advanced.currentProgramId == "block-2")
        #expect(advanced.blockStartedAt == later)
        #expect(advanced.status == .active)
    }

    @Test("Test An Unfinished Block Does Not Move")
    func testAnUnfinishedBlockDoesNotMove() async throws {
        let manager = await TestManagers.signedInTrainingPlanManager()
        let plan = try await manager.startPlan(authorId: "me", name: "Plan", programIds: ["block-1", "block-2"], startedAt: start)
        let progress = ProgramSchedule.progress(of: ProgramSchedule.Run(program: program("block-1"), startedAt: start), sessions: [])

        #expect(try await manager.advanceIfBlockComplete(plan, progress: progress) == nil)
    }

    @Test("Test Finishing The Last Block Completes The Plan And Repeat Starts Over")
    func testFinishingTheLastBlockCompletesThePlan() async throws {
        let manager = await TestManagers.signedInTrainingPlanManager()
        let block = program("block-1")
        let plan = try await manager.startPlan(authorId: "me", name: "Plan", programIds: [block.id], startedAt: start)
        let progress = ProgramSchedule.progress(of: ProgramSchedule.Run(program: block, startedAt: start), sessions: [finished(block, at: start.addingTimeInterval(60))])

        let completed = try #require(try await manager.advanceIfBlockComplete(plan, progress: progress))
        #expect(completed.status == .completed)
        #expect(await TestManagers.eventually { manager.currentPlan?.status == .completed })

        let later = start.addingTimeInterval(600)
        let repeated = try await manager.repeatPlan(completed, now: later)
        #expect(repeated.status == .active)
        #expect(repeated.blockIndex == 0)
        #expect(repeated.blockStartedAt == later)
        #expect(repeated.iteration == 2)
        #expect(repeated.skips.isEmpty)
    }

    @Test("Test A Skip Is Recorded Against The Current Block")
    func testASkipIsRecordedAgainstTheCurrentBlock() async throws {
        let manager = await TestManagers.signedInTrainingPlanManager()
        let block = program("block-1")
        let plan = try await manager.startPlan(authorId: "me", name: "Plan", programIds: [block.id], startedAt: start)
        let slot = try #require(ProgramSchedule.progress(of: ProgramSchedule.Run(program: block, startedAt: start), sessions: []).next)

        let updated = try await manager.skip(slot, in: plan)

        #expect(updated.currentSkips.map(\.templateId) == ["block-1-a"])
        let run = ProgramSchedule.Run(program: block, startedAt: start, skips: updated.currentSkips)
        #expect(ProgramSchedule.progress(of: run, sessions: []).isBlockComplete)
    }
}
