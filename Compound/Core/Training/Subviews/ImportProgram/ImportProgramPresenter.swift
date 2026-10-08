//
//  ImportProgramPresenter.swift
//  Compound
//
//  Import Program: pick a file, read it off the main actor, map the names the library could not
//  match, then save. Nothing is written until Save: new exercises first, then the mesocycles, then
//  the macrocycle (not started).
//

import SwiftUI
import UniformTypeIdentifiers

/// What the screen that opened the importer hears when a program is saved: the macrocycle it
/// became, after the importer has dismissed itself.
struct ImportProgramDelegate {
    var onImported: (@MainActor (Macrocycle) -> Void)?
}

@Observable
@MainActor
class ImportProgramPresenter {

    /// What an unmatched name was mapped to on this screen.
    enum Mapping: Equatable {
        case library(ExerciseModel)
        /// A new exercise of the user's, saved with the program.
        case create(ExerciseModel)

        var exercise: ExerciseModel {
            switch self {
            case .library(let exercise), .create(let exercise): return exercise
            }
        }
    }

    /// What the file holds, for the summary section.
    struct Summary: Equatable {
        var blocks = 0
        var weeks = 0
        var days = 0
        var exercises = 0
        /// The set types other than standard, by name.
        var techniques: [String] = []
        var withWarmups = 0
        var withRest = 0
    }

    private let interactor: ImportProgramInteractor
    private let router: ImportProgramRouter

    var isFileImporterPresented = false
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var fileName: String?
    private(set) var file: ProgramFile?
    /// The names the library did not match, in sheet order. They stay listed once mapped.
    private(set) var reviewNames: [String] = []
    private(set) var mappings: [String: Mapping] = [:]
    private(set) var summary: Summary?
    private var matcher = ExerciseNameMatcher(library: [])

    let contentTypes: [UTType] = [UTType(filenameExtension: "xlsx"), .commaSeparatedText, .json].compactMap { $0 }

    private let delegate: ImportProgramDelegate

    init(interactor: ImportProgramInteractor, router: ImportProgramRouter, delegate: ImportProgramDelegate = ImportProgramDelegate()) {
        self.delegate = delegate
        self.interactor = interactor
        self.router = router
    }

    var hasFile: Bool { file != nil }

    var unmappedNames: [String] {
        reviewNames.filter { mappings[$0] == nil }
    }

    var canSave: Bool {
        hasFile && !isSaving && !isLoading && unmappedNames.isEmpty
    }

    // MARK: - Lifecycle

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onClosePressed() {
        router.dismissEnvironment()
    }

    // MARK: - File

    func onChooseFilePressed() {
        isFileImporterPresented = true
    }

    func onFileImported(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            Task { await importFile(at: url) }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    /// Reads and parses on a background task, then lists what needs mapping.
    func importFile(at url: URL) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let file = try await Task.detached {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                return try ProgramFile.read(Data(contentsOf: url), fileExtension: url.pathExtension)
            }.value
            try load(file, fileName: url.deletingPathExtension().lastPathComponent)
            interactor.trackEvent(event: Event.fileLoaded(format: url.pathExtension.lowercased(), unmatched: reviewNames.count))
        } catch {
            self.file = nil
            summary = nil
            reviewNames = []
            errorMessage = Self.message(for: error)
            interactor.trackEvent(event: Event.fileFailed(error: error))
        }
    }

    private func load(_ file: ProgramFile, fileName: String) throws {
        matcher = ExerciseNameMatcher(library: interactor.allExercises)
        mappings = [:]
        switch file {
        case .sheet(let sheet):
            reviewNames = ProgramImporter.unmatchedNames(in: sheet, resolve: matcher.match)
        case .mesocycles:
            reviewNames = []
        }
        self.file = file
        self.fileName = fileName
        // A trial build with stand-ins for the unmatched names, so a sheet whose weeks disagree
        // is reported now rather than at Save, and the summary reads what Save will create.
        summary = Self.summary(of: try build(stubbingUnmatched: true).mesocycles)
    }

    // MARK: - Mapping

    func status(of name: String) -> String {
        switch mappings[name] {
        case .library(let exercise): return exercise.name
        case .create: return String(localized: "New exercise")
        case nil: return String(localized: "Not matched")
        }
    }

    func onChooseFromLibraryPressed(name: String) {
        interactor.trackEvent(event: Event.chooseFromLibrary)
        router.showImportExercisePickerView(name: name) { [weak self] exercise in
            self?.mappings[name] = .library(exercise)
            self?.interactor.playHaptic(option: .selection)
        }
    }

    func onCreatePressed(name: String) {
        interactor.trackEvent(event: Event.createExercise)
        mappings[name] = .create(newExercise(named: name))
        interactor.playHaptic(option: .selection)
    }

    /// Weight and reps, no muscle groups yet; one-sided when the sheet counts its reps per side.
    private func newExercise(named name: String) -> ExerciseModel {
        ExerciseModel(
            authorId: interactor.userId ?? "",
            name: name,
            trackableMetrics: [.weight, .reps],
            type: nil,
            laterality: isPerSide(name) ? .unilateral : .bilateral,
            muscleGroups: [:],
            isBodyweight: false,
            rangeOfMotion: 0,
            stability: 0,
            bodyWeightContribution: 0,
            alternateNames: []
        )
    }

    private func isPerSide(_ name: String) -> Bool {
        guard case .sheet(let sheet) = file else { return false }
        return sheet.blocks.contains { block in
            block.weeks.contains { week in
                week.days.contains { day in day.rows.contains { $0.exerciseName == name && $0.perSide } }
            }
        }
    }

    // MARK: - Save

    func onSavePressed() {
        Task { await save() }
    }

    func save() async {
        guard canSave else { return }
        guard let userId = interactor.userId else {
            router.showSimpleAlert(title: String(localized: "Unable to Import Program"), subtitle: String(localized: "Please try again."))
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        interactor.trackEvent(event: Event.saveStart)
        do {
            let result = try build(stubbingUnmatched: false, authorId: userId)
            let created = result.newExercises + reviewNames.compactMap { name -> ExerciseModel? in
                guard case .create(let exercise) = mappings[name] else { return nil }
                return exercise
            }
            for exercise in created {
                try await interactor.saveExerciseModel(exercise: exercise, image: nil)
            }
            for mesocycle in result.mesocycles {
                try await interactor.saveMesocycle(mesocycle: mesocycle)
            }
            try await interactor.saveMacrocycle(result.macrocycle)
            interactor.trackEvent(event: Event.saveSuccess(mesocycles: result.mesocycles.count))
            interactor.playHaptic(option: .success)
            router.dismissEnvironment()
            delegate.onImported?(result.macrocycle)
        } catch {
            interactor.trackEvent(event: Event.saveFail(error: error))
            interactor.playHaptic(option: .error)
            errorMessage = Self.message(for: error)
        }
    }

    private func build(stubbingUnmatched: Bool, authorId: String = "") throws -> ProgramImportResult {
        let style = ProgramImportStyle(
            authorId: authorId,
            icon: MesocycleIconPresenter.defaultIcons.first ?? "flag.pattern.checkered",
            colour: (MesocycleIconPresenter.defaultColours.first ?? .primary).asHex()
        )
        switch file {
        case .sheet(let sheet):
            let matcher = matcher
            let mappings = mappings
            return try ProgramImporter.build(sheet, style: style) { name in
                mappings[name]?.exercise ?? matcher.match(name) ?? (stubbingUnmatched ? self.newExercise(named: name) : nil)
            }
        case .mesocycles(let mesocycles):
            return try ProgramImporter.build(mesocycles, title: fileName ?? "", style: style, library: interactor.allExercises)
        case nil:
            throw ProgramImportError.unreadableFile
        }
    }

    // MARK: - Summary

    static func summary(of mesocycles: [Mesocycle]) -> Summary {
        let exercises = mesocycles.flatMap(\.workoutTemplates).flatMap(\.exercises)
        let types = Set(exercises.flatMap { $0.setTargets + $0.setTargetsByMicrocycle.flatMap(\.setTargets) }.map(\.setType))
        return Summary(
            blocks: mesocycles.count,
            weeks: mesocycles.map(\.numMicrocycles).reduce(0, +),
            days: mesocycles.flatMap(\.workoutTemplates).filter { !$0.exercises.isEmpty }.count,
            exercises: exercises.count,
            techniques: types.subtracting([.standard]).map(\.name).sorted(),
            withWarmups: exercises.filter { $0.warmupSetCount != nil }.count,
            withRest: exercises.filter { $0.restSeconds != nil }.count
        )
    }

    /// "Row 12: …" where the error has a row.
    static func message(for error: Error) -> String {
        guard let importError = error as? ProgramImportError else { return error.localizedDescription }
        let description = importError.errorDescription ?? ""
        guard let row = importError.row else { return description }
        return String(localized: "Row \(row): \(description)")
    }
}

extension ImportProgramPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case fileLoaded(format: String, unmatched: Int)
        case fileFailed(error: Error)
        case chooseFromLibrary
        case createExercise
        case saveStart
        case saveSuccess(mesocycles: Int)
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:             return "ImportProgramView_Appear"
            case .onDisappear:          return "ImportProgramView_Disappear"
            case .fileLoaded:           return "ImportProgramView_File_Loaded"
            case .fileFailed:           return "ImportProgramView_File_Fail"
            case .chooseFromLibrary:    return "ImportProgramView_ChooseFromLibrary"
            case .createExercise:       return "ImportProgramView_CreateExercise"
            case .saveStart:            return "ImportProgramView_Save_Start"
            case .saveSuccess:          return "ImportProgramView_Save_Success"
            case .saveFail:             return "ImportProgramView_Save_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .fileLoaded(let format, let unmatched):
                return ["format": format, "unmatched_count": unmatched]
            case .saveSuccess(let mesocycles):
                return ["mesocycle_count": mesocycles]
            case .fileFailed(let error), .saveFail(let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .fileFailed, .saveFail: return .severe
            default: return .analytic
            }
        }
    }
}
