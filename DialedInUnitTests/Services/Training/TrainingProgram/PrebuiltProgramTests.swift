//
//  PrebuiltProgramTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 25/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The shipped program templates: decoding `PrebuiltPrograms.json`, seeding it into
/// `TrainingProgramManager`, and the copy a user gets when they start one.
@MainActor
struct PrebuiltProgramTests {

    private func decode(_ json: String) throws -> PrebuiltProgramDTO {
        try JSONDecoder().decode(PrebuiltProgramDTO.self, from: Data(json.utf8))
    }

    private func makeManager() -> (TrainingProgramManager, UserDefaults) {
        let defaults = TestManagers.scratchDefaults("programs")
        return (TestManagers.trainingProgramManager(userDefaults: defaults), defaults)
    }

    // MARK: - Decoding

    @Test("Test The Bundled File Decodes All Four Programs Against The Shipped Workouts")
    func testTheBundledFileDecodesAllFourPrograms() {
        let programs = PrebuiltSeedData.programs
        #expect(programs.map(\.id) == ["program-push-pull-legs", "program-upper-lower", "program-full-body", "program-531"])
        #expect(programs.allSatisfy { $0.authorId == "official" })
    }

    @Test("Test Each Split Has The Advertised Number Of Training Days")
    func testEachSplitHasTheAdvertisedTrainingDays() {
        let workoutsPerProgram = Dictionary(uniqueKeysWithValues: PrebuiltSeedData.programs.map { program in
            (program.id, program.workoutTemplates.filter { !$0.exercises.isEmpty }.count)
        })
        #expect(workoutsPerProgram == [
            "program-push-pull-legs": 6,
            "program-upper-lower": 4,
            "program-full-body": 3,
            "program-531": 4
        ])
    }

    @Test("Test 5/3/1 Is A Periodised Four Week Wave")
    func testFiveThreeOneIsAPeriodisedFourWeekWave() throws {
        let program = try #require(PrebuiltSeedData.programs.first { $0.id == "program-531" })
        #expect(program.periodisation)
        #expect(program.numMicrocycles == 4)
        #expect(program.deload == .end)
    }

    @Test("Test Rest Entries Become Empty Days And Workout Ids Resolve")
    func testRestEntriesBecomeEmptyDays() throws {
        let dto = try decode("""
        {"programId":"p","name":"P","icon":"flag","colour":"#FF0000","numMicrocycles":6,
         "deload":"start","periodisation":false,"days":["workout-push-1","rest"]}
        """)
        let program = try #require(dto.toModel(workouts: PrebuiltSeedData.workoutTemplates))

        #expect(program.id == "p")
        #expect(program.deload == .start)
        #expect(program.workoutTemplates.map(\.id) == ["workout-push-1", "p-rest-1"])
        #expect(program.workoutTemplates[1].exercises.isEmpty)
    }

    @Test("Test A Program Naming A Missing Workout Is Dropped Whole")
    func testAProgramNamingAMissingWorkoutIsDropped() throws {
        let dto = try decode("""
        {"programId":"p","name":"P","icon":"flag","colour":"#FF0000","numMicrocycles":6,
         "deload":"none","periodisation":false,"days":["workout-push-1","workout-nope"]}
        """)
        #expect(dto.toModel(workouts: PrebuiltSeedData.workoutTemplates) == nil)
    }

    // MARK: - Seeding

    @Test("Test Seeding Twice Leaves One Copy Of Each Program")
    func testSeedingIsIdempotent() throws {
        let (manager, _) = makeManager()
        #expect(manager.prebuiltPrograms.isEmpty)

        try manager.seedProgramsIfNeeded(workouts: PrebuiltSeedData.workoutTemplates)
        let first = manager.prebuiltPrograms.map(\.id).sorted()
        #expect(first.count == 4)
        #expect(manager.hasSeeded)

        try manager.seedProgramsIfNeeded(workouts: PrebuiltSeedData.workoutTemplates)
        #expect(manager.prebuiltPrograms.map(\.id).sorted() == first)
    }

    @Test("Test An Older Version Is Reseeded Without Duplicating")
    func testAnOlderVersionIsReseeded() throws {
        let (manager, defaults) = makeManager()
        try manager.seedProgramsIfNeeded(workouts: PrebuiltSeedData.workoutTemplates)
        defaults.set(0, forKey: TrainingProgramManager.seedingVersionKey)

        try manager.seedProgramsIfNeeded(workouts: PrebuiltSeedData.workoutTemplates)

        #expect(manager.prebuiltPrograms.count == 4)
        #expect(manager.seedingVersion > 0)
    }

    @Test("Test Seeding Before Workouts Exist Does Nothing And Can Retry")
    func testSeedingWithoutWorkoutsIsANoOp() throws {
        let (manager, _) = makeManager()

        try manager.seedProgramsIfNeeded(workouts: [])
        #expect(manager.prebuiltPrograms.isEmpty)
        #expect(!manager.hasSeeded)

        try manager.seedProgramsIfNeeded(workouts: PrebuiltSeedData.workoutTemplates)
        #expect(manager.prebuiltPrograms.count == 4)
    }

    // MARK: - Copy

    @Test("Test Starting A Template Copies It With New Ids And The User As Author")
    func testTheCopyHasNewIdsAndTheUserAsAuthor() throws {
        let template = try #require(PrebuiltSeedData.programs.first { $0.id == "program-push-pull-legs" })

        let copy = TrainingProgramManager.copy(of: template, authorId: "user-1")

        #expect(copy.id != template.id)
        #expect(copy.authorId == "user-1")
        #expect(copy.name == template.name)
        #expect(copy.numMicrocycles == template.numMicrocycles)
        #expect(copy.deload == template.deload)
        #expect(copy.workoutTemplates.count == template.workoutTemplates.count)
        #expect(copy.workoutTemplates.allSatisfy { $0.authorId == "user-1" })
        let originalDayIds = Set(template.workoutTemplates.map(\.id))
        #expect(Set(copy.workoutTemplates.map(\.id)).isDisjoint(with: originalDayIds))
        let originalItemIds = Set(template.workoutTemplates.flatMap(\.exercises).map(\.id))
        #expect(Set(copy.workoutTemplates.flatMap(\.exercises).map(\.id)).isDisjoint(with: originalItemIds))
        // The seeded exercises are shared, not duplicated.
        #expect(copy.workoutTemplates.flatMap(\.exercises).map(\.exercise.id)
            == template.workoutTemplates.flatMap(\.exercises).map(\.exercise.id))
    }
}

// MARK: - Detail screen

@MainActor
struct PrebuiltProgramDetailPresenterTests {

    private final class Interactor: SpyGlobalInteractor, PrebuiltProgramDetailInteractor {
        var error: Error?
        private(set) var started: [String] = []

        func startPrebuiltProgram(_ program: TrainingProgram) async throws -> TrainingProgram {
            if let error { throw error }
            started.append(program.id)
            return program
        }
    }

    private final class Router: PrebuiltProgramDetailRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var dismissed = 0
        private(set) var errors = 0

        func dismissScreen() { dismissed += 1 }
        func showAlert(error: Error) { errors += 1 }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
        func showDevSettingsView() { }
    }

    private struct Failure: Error { }

    @Test("Test Start Copies The Program And Returns To The Library")
    func testStartCopiesAndDismisses() async {
        let interactor = Interactor()
        let router = Router()
        let program = PrebuiltSeedData.programs.first ?? .mock
        let presenter = PrebuiltProgramDetailPresenter(interactor: interactor, router: router, program: program)

        await presenter.onStartPressed()

        #expect(interactor.started == [program.id])
        #expect(router.dismissed == 1)
        #expect(!presenter.isStarting)
    }

    @Test("Test A Failed Start Stays On The Screen And Says So")
    func testAFailedStartShowsAnError() async {
        let interactor = Interactor()
        interactor.error = Failure()
        let router = Router()
        let presenter = PrebuiltProgramDetailPresenter(interactor: interactor, router: router, program: .mock)

        await presenter.onStartPressed()

        #expect(router.dismissed == 0)
        #expect(router.errors == 1)
        #expect(interactor.trackedEventNames.contains("PrebuiltProgramDetailView_Start_Fail"))
    }
}
