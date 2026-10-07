//
//  ImportProgramPresenterTests.swift
//  CompoundUnitTests
//
//  The Import Program screen: read a file, list the names the library did not match, map them
//  (from the library or as new exercises), and save in order — exercises, mesocycles, macrocycle.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

private struct ImportSaveError: Error { }

@MainActor
struct ImportProgramPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ImportProgramInteractor {
        var userId: String? = "user-1"
        var allExercises: [ExerciseModel] = []
        var saveError: Error?
        /// Every save, in order, as "kind:name".
        private(set) var saves: [String] = []
        private(set) var savedExercises: [ExerciseModel] = []
        private(set) var savedMesocycles: [Mesocycle] = []
        private(set) var savedMacrocycles: [Macrocycle] = []

        func saveExerciseModel(exercise: ExerciseModel, image: PlatformImage?) async throws {
            if let saveError { throw saveError }
            saves.append("exercise:\(exercise.name)")
            savedExercises.append(exercise)
        }

        func saveMesocycle(mesocycle: Mesocycle) async throws {
            saves.append("mesocycle:\(mesocycle.name)")
            savedMesocycles.append(mesocycle)
        }

        func saveMacrocycle(_ macrocycle: Macrocycle) async throws {
            saves.append("macrocycle:\(macrocycle.name)")
            savedMacrocycles.append(macrocycle)
        }
    }

    private final class Router: ImportProgramRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var pickerNames: [String] = []
        private(set) var pickerCallbacks: [@MainActor (ExerciseModel) -> Void] = []
        private(set) var dismissals = 0
        private(set) var alertTitles: [String] = []

        func showImportExercisePickerView(name: String, onSelect: @escaping @MainActor (ExerciseModel) -> Void) {
            pickerNames.append(name)
            pickerCallbacks.append(onSelect)
        }

        func dismissEnvironment() { dismissals += 1 }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    private struct Screen {
        let presenter: ImportProgramPresenter
        let interactor: Interactor
        let router: Router
    }

    /// The sample program's library without "Row" and "Leg Press", so two names need mapping.
    private func makeScreen() -> Screen {
        let interactor = Interactor()
        interactor.allExercises = ProgramFixtures.library.filter { !["Row", "Leg Press"].contains($0.name) }
        let router = Router()
        return Screen(presenter: ImportProgramPresenter(interactor: interactor, router: router), interactor: interactor, router: router)
    }

    private func temporaryFile(_ name: String, _ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-\(name)")
        try Data(contents.utf8).write(to: url)
        return url
    }

    @Test("Test Reading A Sheet Lists The Unmatched Names And Summarises It")
    func testParseListsUnmatched() async {
        let screen = makeScreen()

        await screen.presenter.importFile(at: ProgramFixtures.url("sample-program.xlsx"))

        #expect(screen.presenter.errorMessage == nil)
        #expect(screen.presenter.fileName == "sample-program")
        #expect(screen.presenter.reviewNames == ["Row", "Leg Press"])
        #expect(screen.presenter.status(of: "Row") == String(localized: "Not matched"))
        #expect(!screen.presenter.canSave)
        let summary = screen.presenter.summary
        #expect(summary?.blocks == 2)
        #expect(summary?.weeks == 4)
        #expect(summary?.days == 4)
        #expect(summary?.exercises == 17)
        #expect(summary?.techniques.count == 6)
        #expect(summary?.withRest == 16)
        #expect(screen.interactor.trackedEventNames.contains("ImportProgramView_File_Loaded"))
    }

    @Test("Test Mapping One From The Library And Creating One Allows Saving In Order")
    func testMapCreateAndSave() async throws {
        let screen = makeScreen()
        await screen.presenter.importFile(at: ProgramFixtures.url("sample-program.csv"))

        screen.presenter.onChooseFromLibraryPressed(name: "Row")
        #expect(screen.router.pickerNames == ["Row"])
        let barbellRow = ProgramFixtures.exercise("Barbell Row")
        let onSelect = try #require(screen.router.pickerCallbacks.first)
        onSelect(barbellRow)
        #expect(screen.presenter.status(of: "Row") == "Barbell Row")
        #expect(!screen.presenter.canSave)

        screen.presenter.onCreatePressed(name: "Leg Press")
        #expect(screen.presenter.status(of: "Leg Press") == String(localized: "New exercise"))
        #expect(screen.interactor.saves.isEmpty)
        #expect(screen.presenter.canSave)

        await screen.presenter.save()

        #expect(screen.interactor.saves == ["exercise:Leg Press", "mesocycle:Build", "mesocycle:Peak", "macrocycle:Sample Program"])
        let created = try #require(screen.interactor.savedExercises.first)
        #expect(created.authorId == "user-1")
        #expect(created.trackableMetrics == [.weight, .reps])
        #expect(created.muscleGroups.isEmpty)
        let build = try #require(screen.interactor.savedMesocycles.first)
        #expect(build.workoutTemplates[0].exercises[1].exercise.id == barbellRow.id)
        #expect(build.workoutTemplates[1].exercises[0].substituteExerciseIds == ["ex-hack-squat", created.id])
        let macrocycle = try #require(screen.interactor.savedMacrocycles.first)
        #expect(macrocycle.status == .notStarted)
        #expect(macrocycle.mesocycleIds == screen.interactor.savedMesocycles.map(\.id))
        #expect(screen.interactor.playedHaptics.last.map { "\($0)" } == "success")
        #expect(screen.router.dismissals == 1)
    }

    @Test("Test A Created Exercise Done Per Side Is One-Sided")
    func testCreatedPerSide() async throws {
        let screen = makeScreen()
        let csv = "Day,Exercise,Working Sets,Reps\nWeek 1\nLegs,Step Up,3,10 per leg\n"
        await screen.presenter.importFile(at: try temporaryFile("plan.csv", csv))
        screen.presenter.onCreatePressed(name: "Step Up")

        await screen.presenter.save()

        #expect(screen.interactor.savedExercises.first?.laterality == .unilateral)
    }

    @Test("Test A Parse Error Shows Its Row And Leaves Nothing To Save")
    func testParseErrorShowsRow() async throws {
        let screen = makeScreen()
        let csv = "Day,Exercise,Working Sets\nWeek 1\nPush,Squat,3\nWeek 2\nPush,Leg Curl,3\n"

        await screen.presenter.importFile(at: try temporaryFile("plan.csv", csv))

        let message = try #require(screen.presenter.errorMessage)
        #expect(message.contains("5"))
        #expect(message.contains("Week 2"))
        #expect(!screen.presenter.hasFile)
        #expect(!screen.presenter.canSave)
    }

    @Test("Test A Failed Save Shows The Error And Keeps The Screen")
    func testSaveFailure() async {
        let screen = makeScreen()
        await screen.presenter.importFile(at: ProgramFixtures.url("sample-program.csv"))
        screen.presenter.onCreatePressed(name: "Row")
        screen.presenter.onCreatePressed(name: "Leg Press")
        screen.interactor.saveError = ImportSaveError()

        await screen.presenter.save()

        #expect(screen.presenter.errorMessage != nil)
        #expect(screen.interactor.savedMesocycles.isEmpty)
        #expect(screen.interactor.playedHaptics.last.map { "\($0)" } == "error")
        #expect(screen.router.dismissals == 0)
    }

    @Test("Test The App's JSON Needs No Mapping And Saves Its Copied Exercise First")
    func testJSON() async {
        let screen = makeScreen()
        screen.interactor.allExercises = ProgramFixtures.library.filter { $0.name != "Calf Raise" }

        await screen.presenter.importFile(at: ProgramFixtures.url("sample-program.json"))
        #expect(screen.presenter.reviewNames.isEmpty)
        #expect(screen.presenter.canSave)

        await screen.presenter.save()

        #expect(screen.interactor.saves == ["exercise:Calf Raise", "mesocycle:Build", "mesocycle:Peak", "macrocycle:sample-program"])
    }
}
