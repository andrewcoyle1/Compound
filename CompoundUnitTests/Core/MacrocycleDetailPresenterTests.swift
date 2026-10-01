//
//  MacrocycleDetailPresenterTests.swift
//  CompoundUnitTests
//
//  Building and starting a macrocycle: it starts at the beginning unless the user picks where they
//  are, the microcycle choice follows the chosen mesocycle's length, and starting over the one being
//  followed asks first.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// One call to `startMacrocycle`, as the interactor double saw it.
private struct StartCall {
    let macrocycle: Macrocycle
    let mesocycleIndex: Int
    let microcycleIndex: Int
}

@MainActor
struct MacrocycleDetailPresenterTests {

    private final class Interactor: SpyGlobalInteractor, MacrocycleDetailInteractor {
        var userId: String? = "me"
        var mesocycles: [Mesocycle] = []
        var currentMacrocycle: Macrocycle?
        private(set) var saved: [Macrocycle] = []
        private(set) var started: [StartCall] = []
        private(set) var deleted: [String] = []

        func saveMacrocycle(_ macrocycle: Macrocycle) async throws { saved.append(macrocycle) }
        func startMacrocycle(_ macrocycle: Macrocycle, atMesocycle mesocycleIndex: Int, microcycle microcycleIndex: Int) async throws {
            started.append(StartCall(macrocycle: macrocycle, mesocycleIndex: mesocycleIndex, microcycleIndex: microcycleIndex))
        }
        func deleteMacrocycle(_ macrocycle: Macrocycle) async throws { deleted.append(macrocycle.id) }
    }

    private final class Router: MacrocycleDetailRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showAlert(error: Error) { alertTitles.append("Error") }
    }

    private func mesocycle(_ id: String, microcycles: Int) -> Mesocycle {
        Mesocycle(id: id, authorId: "me", name: id.capitalized, icon: "dumbbell", colour: "#FF0000", numMicrocycles: microcycles)
    }

    private struct Screen {
        let presenter: MacrocycleDetailPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(macrocycle: Macrocycle? = nil, current: Macrocycle? = nil) -> Screen {
        let interactor = Interactor()
        interactor.mesocycles = [mesocycle("hypertrophy", microcycles: 6), mesocycle("strength", microcycles: 4)]
        interactor.currentMacrocycle = current
        let router = Router()
        let presenter = MacrocycleDetailPresenter(interactor: interactor, router: router, delegate: MacrocycleDetailDelegate(macrocycle: macrocycle))
        return Screen(presenter: presenter, interactor: interactor, router: router)
    }

    @Test("Test A New Macrocycle Starts At The Beginning By Default")
    func testANewMacrocycleStartsAtTheBeginningByDefault() async throws {
        let screen = makeScreen()
        let presenter = screen.presenter, interactor = screen.interactor
        presenter.onAddMesocyclePressed(interactor.mesocycles[0])
        presenter.onAddMesocyclePressed(interactor.mesocycles[1])

        #expect(presenter.name == "Hypertrophy")
        presenter.onStartPressed()

        #expect(await TestManagers.eventually { interactor.started.count == 1 })
        let start = try #require(interactor.started.first)
        #expect(start.macrocycle.mesocycleIds == ["hypertrophy", "strength"])
        #expect(start.macrocycle.status == .notStarted)
        #expect(start.mesocycleIndex == 0)
        #expect(start.microcycleIndex == 0)
    }

    @Test("Test Joining Part-Way Starts At The Chosen Mesocycle And Microcycle")
    func testJoiningPartWayStartsAtTheChosenPoint() async throws {
        let screen = makeScreen()
        let presenter = screen.presenter, interactor = screen.interactor
        presenter.onAddMesocyclePressed(interactor.mesocycles[0])
        presenter.onAddMesocyclePressed(interactor.mesocycles[1])

        presenter.startMesocycleIndex = 1
        presenter.startMicrocycleIndex = 2
        presenter.onStartPressed()

        #expect(await TestManagers.eventually { interactor.started.count == 1 })
        #expect(interactor.started.first?.mesocycleIndex == 1)
        #expect(interactor.started.first?.microcycleIndex == 2)
    }

    @Test("Test The Microcycle Choice Follows The Chosen Mesocycle's Length")
    func testTheMicrocycleChoiceFollowsTheMesocyclesLength() {
        let screen = makeScreen()
        let presenter = screen.presenter, interactor = screen.interactor
        presenter.onAddMesocyclePressed(interactor.mesocycles[0])
        presenter.onAddMesocyclePressed(interactor.mesocycles[1])
        #expect(presenter.startMicrocycleCount == 6)

        presenter.startMicrocycleIndex = 5
        presenter.startMesocycleIndex = 1

        #expect(presenter.startMicrocycleCount == 4)
        #expect(presenter.startMicrocycleIndex == 3)
    }

    @Test("Test Removing The Chosen Mesocycle Keeps The Start Point In Range")
    func testRemovingTheChosenMesocycleKeepsTheStartPointInRange() {
        let screen = makeScreen()
        let presenter = screen.presenter, interactor = screen.interactor
        presenter.onAddMesocyclePressed(interactor.mesocycles[0])
        presenter.onAddMesocyclePressed(interactor.mesocycles[1])
        presenter.startMesocycleIndex = 1

        presenter.onDeleteMesocycles(at: IndexSet(integer: 1))

        #expect(presenter.startMesocycleIndex == 0)
    }

    @Test("Test Starting While Another Macrocycle Is Followed Asks First")
    func testStartingWhileAnotherIsFollowedAsksFirst() {
        let following = Macrocycle(authorId: "me", name: "Current", mesocycleIds: ["strength"], status: .active)
        let screen = makeScreen(current: following)
        let presenter = screen.presenter, interactor = screen.interactor, router = screen.router
        presenter.onAddMesocyclePressed(interactor.mesocycles[0])

        presenter.onStartPressed()

        #expect(router.alertTitles == ["Replace Current?"])
        #expect(interactor.started.isEmpty)
    }

    @Test("Test Starting The Followed Macrocycle Again Is A Restart")
    func testStartingTheFollowedMacrocycleAgainIsARestart() {
        let following = Macrocycle(authorId: "me", name: "Current", mesocycleIds: ["strength"], status: .active)
        let screen = makeScreen(macrocycle: following, current: following)
        let presenter = screen.presenter, router = screen.router

        #expect(presenter.startButtonTitle == "Restart Macrocycle")
        presenter.onStartPressed()

        #expect(router.alertTitles == ["Restart Current?"])
    }

    @Test("Test Saving Keeps Edits Without Starting")
    func testSavingKeepsEditsWithoutStarting() async {
        let screen = makeScreen()
        let presenter = screen.presenter, interactor = screen.interactor
        presenter.onAddMesocyclePressed(interactor.mesocycles[1])
        presenter.name = "  Off-season  "

        presenter.onSavePressed()

        #expect(await TestManagers.eventually { interactor.saved.count == 1 })
        #expect(interactor.saved.first?.name == "Off-season")
        #expect(interactor.saved.first?.status == .notStarted)
        #expect(interactor.started.isEmpty)
    }

    @Test("Test Nothing Can Be Saved Without A Name And A Mesocycle")
    func testNothingCanBeSavedWithoutANameAndAMesocycle() {
        let screen = makeScreen()
        let presenter = screen.presenter, interactor = screen.interactor
        #expect(!presenter.canSave)
        presenter.name = "Season"
        #expect(!presenter.canSave)
        presenter.onAddMesocyclePressed(interactor.mesocycles[0])
        #expect(presenter.canSave)
    }
}
