//
//  ProgramImporter.swift
//  Compound
//
//  A parsed program as mesocycles in a macrocycle that has not been started.
//
//  - Each block is a mesocycle of its weeks; its days, in week 1's order, are the templates (a
//    rest day is an empty template named "Rest"). `deload` is none: the sheet spells its deload
//    week out.
//  - Week 1's targets are the base; a later week adds a `MicrocycleSetTargets` override only
//    where an exercise's targets differ from the week before.
//  - Every week must have week 1's days, each with week 1's exercises by name, else the error
//    names the week and day.
//  - Rows sharing a superset tag on a day share a `supersetGroupId`.
//  - Every name (exercises and substitutions) must resolve before anything is built.
//
//  The app's own JSON — a `[Mesocycle]` or a single `Mesocycle` — is copied under the user, the
//  way a shared mesocycle is accepted, and wrapped in a macrocycle the same way.
//

import Foundation

/// A file read and parsed, before any name is matched.
enum ProgramFile: Sendable {
    case sheet(ProgramSheet)
    case mesocycles([Mesocycle])

    /// Reads `.xlsx`, `.csv` or `.json`, by extension.
    static func read(_ data: Data, fileExtension: String) throws -> ProgramFile {
        switch fileExtension.lowercased() {
        case "xlsx": return .sheet(try ProgramSheetParser.parse(XLSXReader.grid(from: data)))
        case "csv": return .sheet(try ProgramSheetParser.parse(CSVReader.grid(from: data)))
        case "json": return .mesocycles(try ProgramImporter.mesocycles(fromJSON: data))
        default: throw ProgramImportError.unreadableFile
        }
    }
}

struct ProgramImportResult {
    var macrocycle: Macrocycle
    var mesocycles: [Mesocycle]
    /// Exercises a JSON program used that are neither built in nor the user's own, copied under
    /// the user. Saved before the mesocycles.
    var newExercises: [ExerciseModel] = []
}

/// How the importer names and draws what it creates.
struct ProgramImportStyle {
    var authorId: String
    var icon: String
    var colour: String
}

enum ProgramImporter {

    /// Every exercise and substitution name `resolve` cannot match, once each, in sheet order.
    static func unmatchedNames(in sheet: ProgramSheet, resolve: (String) -> ExerciseModel?) -> [String] {
        var seen = Set<String>()
        var unmatched: [String] = []
        for block in sheet.blocks {
            for week in block.weeks {
                for day in week.days {
                    for row in day.rows {
                        for name in [row.exerciseName] + row.substitutions where seen.insert(name).inserted && resolve(name) == nil {
                            unmatched.append(name)
                        }
                    }
                }
            }
        }
        return unmatched
    }

    static func build(
        _ sheet: ProgramSheet,
        style: ProgramImportStyle,
        resolve: (String) -> ExerciseModel?
    ) throws -> ProgramImportResult {
        let unmatched = unmatchedNames(in: sheet, resolve: resolve)
        guard unmatched.isEmpty else { throw ProgramImportError.unmatchedExercises(unmatched) }

        let mesocycles = try sheet.blocks.filter { !$0.weeks.isEmpty }.map { block in
            try validate(block)
            return Mesocycle(
                authorId: style.authorId,
                name: block.name,
                icon: style.icon,
                colour: style.colour,
                numMicrocycles: block.weeks.count,
                deload: .none,
                workoutTemplates: block.weeks[0].days.indices.map { index in
                    template(day: index, of: block, authorId: style.authorId, resolve: resolve)
                }
            )
        }
        guard !mesocycles.isEmpty else { throw ProgramImportError.noExercises }
        return ProgramImportResult(
            macrocycle: Macrocycle(
                authorId: style.authorId,
                name: sheet.title ?? mesocycles[0].name,
                mesocycleIds: mesocycles.map(\.id),
                status: .notStarted
            ),
            mesocycles: mesocycles
        )
    }

    // MARK: - Blocks

    private static func validate(_ block: ProgramSheet.Block) throws {
        let base = block.weeks[0]
        for week in block.weeks.dropFirst() {
            guard week.days.map(\.name) == base.days.map(\.name) else {
                throw ProgramImportError.daysDiffer(week: week.label, row: week.days.first?.sourceRow ?? 0)
            }
            for (day, baseDay) in zip(week.days, base.days) where day.rows.map(\.exerciseName) != baseDay.rows.map(\.exerciseName) {
                throw ProgramImportError.exercisesDiffer(week: week.label, day: day.name, row: day.sourceRow)
            }
        }
    }

    private static func template(
        day index: Int,
        of block: ProgramSheet.Block,
        authorId: String,
        resolve: (String) -> ExerciseModel?
    ) -> WorkoutTemplateModel {
        let day = block.weeks[0].days[index]
        guard !day.isRest else { return WorkoutTemplateModel(authorId: authorId, name: "Rest", exercises: []) }

        let groupIds = Dictionary(uniqueKeysWithValues: Set(day.rows.compactMap(\.supersetTag)).map { ($0, UUID().uuidString) })
        let exercises = day.rows.indices.compactMap { rowIndex -> WorkoutTemplateExercise? in
            let row = day.rows[rowIndex]
            guard let exercise = resolve(row.exerciseName) else { return nil }
            let base = setTargets(for: row)
            var previous = base
            var overrides: [MicrocycleSetTargets] = []
            for (weekIndex, week) in block.weeks.enumerated().dropFirst() {
                let targets = setTargets(for: week.days[index].rows[rowIndex])
                if !sameTargets(targets, previous) {
                    overrides.append(MicrocycleSetTargets(fromMicrocycle: weekIndex + 1, setTargets: targets))
                }
                previous = targets
            }
            return WorkoutTemplateExercise(
                exercise: exercise,
                setTargets: base,
                setRestTimers: false,
                notes: row.notes,
                warmupSetCount: warmupSetCount(for: row),
                restSeconds: restSeconds(for: row),
                substituteExerciseIds: row.substitutions.compactMap { resolve($0)?.id },
                supersetGroupId: row.supersetTag.flatMap { groupIds[$0] },
                linkURL: row.linkURL,
                setTargetsByMicrocycle: overrides
            )
        }
        return WorkoutTemplateModel(authorId: authorId, name: day.name, exercises: exercises)
    }

    /// Equal apart from the ids, which are new on every build.
    private static func sameTargets(_ lhs: [SetTarget], _ rhs: [SetTarget]) -> Bool {
        func withoutIds(_ targets: [SetTarget]) -> [SetTarget] {
            targets.map { target in
                var target = target
                target.id = ""
                return target
            }
        }
        return withoutIds(lhs) == withoutIds(rhs)
    }

    // MARK: - JSON

    /// A `[Mesocycle]` array or a single `Mesocycle`, in the app's own Codable form.
    static func mesocycles(fromJSON data: Data) throws -> [Mesocycle] {
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([Mesocycle].self, from: data) { return list }
        do {
            return [try decoder.decode(Mesocycle.self, from: data)]
        } catch {
            throw ProgramImportError.unreadableFile
        }
    }

    /// The user's own copies of `mesocycles`, in a macrocycle named `title`.
    static func build(
        _ mesocycles: [Mesocycle],
        title: String,
        style: ProgramImportStyle,
        library: [ExerciseModel]
    ) throws -> ProgramImportResult {
        guard !mesocycles.isEmpty else { throw ProgramImportError.noExercises }
        // Copied as one, so an exercise that several mesocycles use becomes one copy, then split
        // back by each mesocycle's day count (the copier keeps the order).
        let together = Mesocycle(
            authorId: style.authorId, name: title, icon: style.icon, colour: style.colour,
            workoutTemplates: mesocycles.flatMap(\.workoutTemplates)
        )
        let copied = SharedItemCopier.copy(.mesocycle(together), recipientId: style.authorId, library: library)
        guard case .mesocycle(let flat) = copied.payload else { throw ProgramImportError.unreadableFile }
        var remaining = flat.workoutTemplates[...]
        let copies = mesocycles.map { mesocycle in
            let days = Array(remaining.prefix(mesocycle.workoutTemplates.count))
            remaining = remaining.dropFirst(mesocycle.workoutTemplates.count)
            return Mesocycle(
                authorId: style.authorId,
                name: mesocycle.name,
                icon: mesocycle.icon,
                colour: mesocycle.colour,
                numMicrocycles: mesocycle.numMicrocycles,
                deload: mesocycle.deload,
                periodisation: mesocycle.periodisation,
                workoutTemplates: days
            )
        }
        return ProgramImportResult(
            macrocycle: Macrocycle(
                authorId: style.authorId,
                name: copies.count == 1 ? copies[0].name : title,
                mesocycleIds: copies.map(\.id),
                status: .notStarted
            ),
            mesocycles: copies,
            newExercises: copied.newExercises
        )
    }
}
