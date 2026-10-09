//
//  ProgramSheetParser.swift
//  Compound
//
//  A grid (from `XLSXReader` or `CSVReader`) as a `ProgramSheet`.
//
//  - A header row is any row with a cell reading "Exercise"; it sets the columns, by name, until
//    the next header row (a later block may track effort differently). Unknown columns, such as
//    "Set 1"… tracking columns, are ignored.
//  - The first column carries the structure. "Week N", "Intro Week" and "Deload Week" start a
//    week; "Rest Day" is a rest day; a name on an exercise row starts a day, which carries on
//    over the rows below until another name. A line of its own that is followed by a week or a
//    header starts a block (its text is the mesocycle's name); the first such line of the sheet
//    is the program's title instead.
//  - A sheet with no block lines is one block named after the title; one with no week lines is
//    one week.
//

import Foundation

enum ProgramSheetParser {

    /// Where each value is, by column index.
    struct Columns {
        var exercise: Int
        /// Where the week label sits on the header row, and so where the day names sit on the
        /// exercise rows: the first named column before Exercise. Nil when Exercise comes first,
        /// so days can only be lines of their own.
        var marker: Int?
        var technique: Int?
        var warmupSets: Int?
        var workingSets: Int?
        var reps: Int?
        var earlyRPE: Int?
        var lastRPE: Int?
        var rir: [Int] = []
        var rest: Int?
        var substitutions: [Int] = []
        var notes: Int?

        init?(header: [SheetCell?]) {
            let names = header.map { $0?.text.trimmingCharacters(in: .whitespaces).lowercased() ?? "" }
            guard let exercise = names.firstIndex(of: "exercise") else { return nil }
            self.exercise = exercise
            marker = names.firstIndex { !$0.isEmpty }.flatMap { $0 < exercise ? $0 : nil }
            // The first rule a name meets places it; a later column of the same kind is ignored.
            let rules: [(WritableKeyPath<Columns, Int?>, (String) -> Bool)] = [
                (\.technique, { $0.contains("intensity") || $0.contains("technique") }),
                (\.warmupSets, { $0.hasPrefix("warm") }),
                (\.workingSets, { $0.hasPrefix("working sets") || $0 == "sets" }),
                (\.reps, { $0.hasPrefix("reps") || $0.hasPrefix("rep range") }),
                (\.earlyRPE, { $0.hasPrefix("early") && $0.contains("rpe") }),
                (\.lastRPE, { $0.hasPrefix("last") && $0.contains("rpe") }),
                (\.rest, { $0.hasPrefix("rest") }),
                (\.notes, { $0.hasPrefix("notes") })
            ]
            var rirColumns: [(set: Int, column: Int)] = []
            for (column, name) in names.enumerated() where column != exercise && !name.isEmpty {
                if name.hasPrefix("rir") {
                    let set = name.firstMatch(of: #/\d+/#).flatMap { Int($0.0) } ?? rirColumns.count + 1
                    rirColumns.append((set, column))
                } else if name.hasPrefix("substitution") {
                    substitutions.append(column)
                } else if let rule = rules.first(where: { $0.1(name) }), self[keyPath: rule.0] == nil {
                    self[keyPath: rule.0] = column
                }
            }
            rir = rirColumns.sorted { $0.set < $1.set }.map(\.column)
        }

        /// RIR columns named on a line under the header ("Failure?" above, "RIR (Set 1)…" below),
        /// taken when the header named none. Any other name on such a line is left alone.
        mutating func absorbRIRColumns(from cells: [SheetCell?]) {
            guard rir.isEmpty else { return }
            let names = cells.map { $0?.text.trimmingCharacters(in: .whitespaces).lowercased() ?? "" }
            let found = names.enumerated().filter { $0.element.hasPrefix("rir") }.map { column, name in
                (set: name.firstMatch(of: #/\d+/#).flatMap { Int($0.0) } ?? column, column: column)
            }
            rir = found.sorted { $0.set < $1.set }.map(\.column)
        }
    }

    static func parse(_ grid: SheetGrid) throws -> ProgramSheet {
        var builder = Builder()
        var columns: Columns?

        for (index, cells) in grid.enumerated() {
            let rowNumber = index + 1
            func cell(_ column: Int?) -> SheetCell? {
                guard let column, cells.indices.contains(column) else { return nil }
                return cells[column]
            }
            guard cells.contains(where: { text($0) != nil }) else { continue }

            if let header = Columns(header: cells) {
                columns = header
                if let marker = text(cell(header.marker)), isWeek(marker) { builder.startWeek(marker) }
                builder.sawHeader = true
                continue
            }
            if lineWithoutExercise(cells, at: index, in: grid, columns: &columns, builder: &builder) { continue }
            if let columns, let name = text(cell(columns.exercise)) {
                if let marker = text(cell(columns.marker)).map(dayName), !isWeek(marker), marker != builder.currentDayName {
                    builder.startDay(marker, row: rowNumber)
                }
                builder.append(try row(name: name, cells: cell, columns: columns, number: rowNumber), row: rowNumber)
                continue
            }
            if let marker = text(cell(columns?.marker ?? 0)) { structuralLine(marker, at: index, in: grid, builder: &builder) }
        }

        guard builder.sawHeader else { throw ProgramImportError.noHeaderRow }
        let sheet = builder.finish()
        guard sheet.blocks.contains(where: { $0.weeks.contains { $0.days.contains { !$0.rows.isEmpty } } }) else {
            throw ProgramImportError.noExercises
        }
        return sheet
    }

    /// The lines that carry no exercise: "RIR (Set 1)…" named under the header with no exercise
    /// beside them, and a line of its own, whichever column it sits in and however far a merged
    /// cell has carried it across the row (a week, a block, a rest day, the title, or a day).
    /// True when the line was one of those.
    private static func lineWithoutExercise(
        _ cells: [SheetCell?],
        at index: Int,
        in grid: SheetGrid,
        columns: inout Columns?,
        builder: inout Builder
    ) -> Bool {
        let exercise = columns.flatMap { cells.indices.contains($0.exercise) ? text(cells[$0.exercise]) : nil }
        if var header = columns, exercise == nil,
           cells.contains(where: { text($0)?.lowercased().hasPrefix("rir") == true }) {
            header.absorbRIRColumns(from: cells)
            columns = header
            return true
        }
        let distinct = Set(cells.compactMap(text))
        guard distinct.count == 1, let only = distinct.first else { return false }
        structuralLine(only, at: index, in: grid, builder: &builder)
        return true
    }

    /// A line with no exercise: a week, a rest day, the title, a block or a day of its own.
    private static func structuralLine(_ marker: String, at index: Int, in grid: SheetGrid, builder: inout Builder) {
        if isWeek(marker) {
            builder.startWeek(marker)
        } else if marker.lowercased().hasPrefix("rest") {
            builder.addRestDay(marker, row: index + 1)
        } else if builder.title == nil && !builder.sawHeader && builder.blocks.isEmpty {
            builder.title = marker
        } else if startsBlock(after: index, in: grid) {
            builder.pendingBlockName = marker
        } else if builder.currentWeekStarted {
            builder.startDay(dayName(marker), row: index + 1)
        }
    }

    // MARK: - Rows

    private static func row(
        name: String,
        cells cell: (Int?) -> SheetCell?,
        columns: Columns,
        number: Int
    ) throws -> ProgramSheet.Row {
        guard let workingSets = range(cell(columns.workingSets)).map({ Int($0.high.rounded()) }), workingSets > 0 else {
            throw ProgramImportError.missingWorkingSets(row: number)
        }
        let (tag, exerciseName) = supersetTag(name)
        let restValue = rest(cell(columns.rest))
        return ProgramSheet.Row(
            exerciseName: exerciseName,
            supersetTag: tag,
            technique: text(cell(columns.technique)),
            warmupSets: range(cell(columns.warmupSets)),
            workingSets: workingSets,
            reps: range(cell(columns.reps)),
            perSide: isPerSide(cell(columns.reps)),
            earlyRPE: range(cell(columns.earlyRPE)),
            lastRPE: range(cell(columns.lastRPE)),
            rirPerSet: columns.rir.map { column in range(cell(column)).map { Int($0.low.rounded()) } },
            rest: restValue?.0,
            restUnit: restValue?.1 ?? .seconds,
            substitutions: columns.substitutions.compactMap { text(cell($0)) },
            notes: text(cell(columns.notes)),
            linkURL: cell(columns.exercise)?.hyperlink,
            sourceRow: number
        )
    }

    // MARK: - Structure

    /// A day's name with its line breaks and runs of spaces collapsed: a sheet wraps "Lower
    /// (Strength Focus)" inside its cell.
    static func dayName(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func isWeek(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.wholeMatch(of: #/week\s*\d+.*/#) != nil || lowered.hasSuffix(" week")
    }

    /// A line of its own starts a block when the next line with anything on it is a week or a
    /// header row.
    private static func startsBlock(after index: Int, in grid: SheetGrid) -> Bool {
        for cells in grid.dropFirst(index + 1) where cells.contains(where: { text($0) != nil }) {
            if Columns(header: cells) != nil { return true }
            let distinct = Set(cells.compactMap(text))
            return distinct.count == 1 && distinct.contains(where: isWeek)
        }
        return false
    }

    /// Accumulates blocks, weeks and days as the rows go by.
    private struct Builder {
        var title: String?
        var sawHeader = false
        var pendingBlockName: String?
        private(set) var blocks: [ProgramSheet.Block] = []
        private var week: ProgramSheet.Week?
        private var day: ProgramSheet.Day?

        var currentDayName: String? { day?.name }
        var currentWeekStarted: Bool { week != nil }

        mutating func startWeek(_ label: String) {
            closeWeek()
            if let pendingBlockName {
                blocks.append(ProgramSheet.Block(name: pendingBlockName, weeks: []))
                self.pendingBlockName = nil
            }
            week = ProgramSheet.Week(label: label, days: [])
        }

        mutating func startDay(_ name: String, row: Int) {
            closeDay()
            if week == nil { startWeek(String(localized: "Week 1")) }
            day = ProgramSheet.Day(name: name, isRest: false, rows: [], sourceRow: row)
        }

        mutating func addRestDay(_ name: String, row: Int) {
            startDay(name, row: row)
            day?.isRest = true
            closeDay()
        }

        mutating func append(_ row: ProgramSheet.Row, row number: Int) {
            if day == nil { startDay(String(localized: "Day 1"), row: number) }
            day?.rows.append(row)
        }

        mutating func finish() -> ProgramSheet {
            closeWeek()
            return ProgramSheet(title: title, blocks: blocks)
        }

        private mutating func closeDay() {
            guard let day else { return }
            week?.days.append(day)
            self.day = nil
        }

        /// A week with no days ("Intro Week" on its own line, then the "Week 1" header) is not a
        /// week of its own: the header's week takes its place.
        private mutating func closeWeek() {
            closeDay()
            guard let week, !week.days.isEmpty else { self.week = nil; return }
            if blocks.isEmpty { blocks.append(ProgramSheet.Block(name: title ?? String(localized: "Imported Program"), weeks: [])) }
            blocks[blocks.count - 1].weeks.append(week)
            self.week = nil
        }
    }
}
