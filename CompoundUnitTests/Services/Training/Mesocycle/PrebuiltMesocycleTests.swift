//
//  PrebuiltMesocycleTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 25/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The shipped mesocycle templates: decoding `PrebuiltMesocycles.json`, seeding it into
/// `MesocycleManager`, and the copy a user gets when they start one.
@MainActor
struct PrebuiltMesocycleTests {

    private func decode(_ json: String) throws -> PrebuiltMesocycleDTO {
        try JSONDecoder().decode(PrebuiltMesocycleDTO.self, from: Data(json.utf8))
    }

    private func makeManager() -> (MesocycleManager, UserDefaults) {
        let defaults = TestManagers.scratchDefaults("programs")
        return (TestManagers.mesocycleManager(userDefaults: defaults), defaults)
    }

    // MARK: - Decoding

    @Test("Test The Bundled File Decodes All Four Programs Against The Shipped Workouts")
    func testTheBundledFileDecodesAllFourMesocycles() {
        let mesocycles = PrebuiltSeedData.mesocycles
        #expect(mesocycles.map(\.id) == ["program-push-pull-legs", "program-upper-lower", "program-full-body", "program-531"])
        #expect(mesocycles.allSatisfy { $0.authorId == "official" })
    }

    @Test("Test Each Split Has The Advertised Number Of Training Days")
    func testEachSplitHasTheAdvertisedTrainingDays() {
        let workoutsPerMesocycle = Dictionary(uniqueKeysWithValues: PrebuiltSeedData.mesocycles.map { mesocycle in
            (mesocycle.id, mesocycle.workoutTemplates.filter { !$0.exercises.isEmpty }.count)
        })
        #expect(workoutsPerMesocycle == [
            "program-push-pull-legs": 6,
            "program-upper-lower": 4,
            "program-full-body": 3,
            "program-531": 4
        ])
    }

    @Test("Test 5/3/1 Is A Periodised Four Week Wave")
    func testFiveThreeOneIsAPeriodisedFourWeekWave() throws {
        let mesocycle = try #require(PrebuiltSeedData.mesocycles.first { $0.id == "program-531" })
        #expect(mesocycle.periodisation)
        #expect(mesocycle.numMicrocycles == 4)
        #expect(mesocycle.deload == .end)
    }

    @Test("Test Rest Entries Become Empty Days And Workout Ids Resolve")
    func testRestEntriesBecomeEmptyDays() throws {
        let dto = try decode("""
        {"mesocycleId":"p","name":"P","icon":"flag","colour":"#FF0000","numMicrocycles":6,
         "deload":"start","periodisation":false,"days":["workout-push-1","rest"]}
        """)
        let mesocycle = try #require(dto.toModel(workouts: PrebuiltSeedData.workoutTemplates))

        #expect(mesocycle.id == "p")
        #expect(mesocycle.deload == .start)
        #expect(mesocycle.workoutTemplates.map(\.id) == ["workout-push-1", "p-rest-1"])
        #expect(mesocycle.workoutTemplates[1].exercises.isEmpty)
    }

    @Test("Test A Program Naming A Missing Workout Is Dropped Whole")
    func testAMesocycleNamingAMissingWorkoutIsDropped() throws {
        let dto = try decode("""
        {"mesocycleId":"p","name":"P","icon":"flag","colour":"#FF0000","numMicrocycles":6,
         "deload":"none","periodisation":false,"days":["workout-push-1","workout-nope"]}
        """)
        #expect(dto.toModel(workouts: PrebuiltSeedData.workoutTemplates) == nil)
    }

    // MARK: - Seeding

    @Test("Test Seeding Twice Leaves One Copy Of Each Program")
    func testSeedingIsIdempotent() throws {
        let (manager, _) = makeManager()
        #expect(manager.prebuiltMesocycles.isEmpty)

        try manager.seedMesocyclesIfNeeded(workouts: PrebuiltSeedData.workoutTemplates)
        let first = manager.prebuiltMesocycles.map(\.id).sorted()
        #expect(first.count == 4)
        #expect(manager.hasSeeded)

        try manager.seedMesocyclesIfNeeded(workouts: PrebuiltSeedData.workoutTemplates)
        #expect(manager.prebuiltMesocycles.map(\.id).sorted() == first)
    }

    @Test("Test An Older Version Is Reseeded Without Duplicating")
    func testAnOlderVersionIsReseeded() throws {
        let (manager, defaults) = makeManager()
        try manager.seedMesocyclesIfNeeded(workouts: PrebuiltSeedData.workoutTemplates)
        defaults.set(0, forKey: MesocycleManager.seedingVersionKey)

        try manager.seedMesocyclesIfNeeded(workouts: PrebuiltSeedData.workoutTemplates)

        #expect(manager.prebuiltMesocycles.count == 4)
        #expect(manager.seedingVersion > 0)
    }

    @Test("Test Seeding Before Workouts Exist Does Nothing And Can Retry")
    func testSeedingWithoutWorkoutsIsANoOp() throws {
        let (manager, _) = makeManager()

        try manager.seedMesocyclesIfNeeded(workouts: [])
        #expect(manager.prebuiltMesocycles.isEmpty)
        #expect(!manager.hasSeeded)

        try manager.seedMesocyclesIfNeeded(workouts: PrebuiltSeedData.workoutTemplates)
        #expect(manager.prebuiltMesocycles.count == 4)
    }

    // MARK: - Copy

    @Test("Test Starting A Template Copies It With New Ids And The User As Author")
    func testTheCopyHasNewIdsAndTheUserAsAuthor() throws {
        let template = try #require(PrebuiltSeedData.mesocycles.first { $0.id == "program-push-pull-legs" })

        let copy = MesocycleManager.copy(of: template, authorId: "user-1")

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
struct PrebuiltMesocycleDetailPresenterTests {

    private final class Interactor: SpyGlobalInteractor, PrebuiltMesocycleDetailInteractor {
        var error: Error?
        private(set) var started: [String] = []

        func startPrebuiltMesocycle(_ mesocycle: Mesocycle) async throws -> Mesocycle {
            if let error { throw error }
            started.append(mesocycle.id)
            return mesocycle
        }
    }

    private final class Router: PrebuiltMesocycleDetailRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var dismissed = 0
        private(set) var errors = 0

        func dismissScreen() { dismissed += 1 }
        func showAlert(error: Error) { errors += 1 }
        func showAlert(title: String, error: Error) { errors += 1 }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
        func showDevSettingsView() { }
    }

    private struct Failure: Error { }

    @Test("Test Start Copies The Program And Returns To The Library")
    func testStartCopiesAndDismisses() async {
        let interactor = Interactor()
        let router = Router()
        let mesocycle = PrebuiltSeedData.mesocycles.first ?? .mock
        let presenter = PrebuiltMesocycleDetailPresenter(interactor: interactor, router: router, mesocycle: mesocycle)

        await presenter.onStartPressed()

        #expect(interactor.started == [mesocycle.id])
        #expect(router.dismissed == 1)
        #expect(!presenter.isStarting)
        #expect(interactor.playedHaptics.map { "\($0)" } == ["success"])
    }

    @Test("Test A Failed Start Stays On The Screen And Says So")
    func testAFailedStartShowsAnError() async {
        let interactor = Interactor()
        interactor.error = Failure()
        let router = Router()
        let presenter = PrebuiltMesocycleDetailPresenter(interactor: interactor, router: router, mesocycle: .mock)

        await presenter.onStartPressed()

        #expect(router.dismissed == 0)
        #expect(router.errors == 1)
        #expect(interactor.trackedEventNames.contains("PrebuiltProgramDetailView_Start_Fail"))
        #expect(interactor.playedHaptics.map { "\($0)" } == ["error"])
    }
}
