//
//  ProgramSheet.swift
//  Compound
//
//  A training program as read from a spreadsheet, before any exercise name is matched to the
//  library: blocks of weeks of days of exercise rows, every value still as the sheet wrote it.
//  `ProgramSheetParser` builds it from a grid; `ProgramImporter` turns it into mesocycles.
//

import Foundation

/// One cell of a sheet. `text` is what the cell shows; `date` is set when the cell holds a date
/// (Excel turns "6-8" typed into a cell into 8 June), and `number` when it holds a number.
struct SheetCell: Equatable, Sendable {
    var text: String
    var date: Date?
    var number: Double?
    var hyperlink: String?

    init(text: String, date: Date? = nil, number: Double? = nil, hyperlink: String? = nil) {
        self.text = text
        self.date = date
        self.number = number
        self.hyperlink = hyperlink
    }
}

/// Rows of cells, top to bottom; a missing cell is nil.
typealias SheetGrid = [[SheetCell?]]

/// A low–high pair: "6-8" is 6…8, "20" is 20…20.
struct ValueRange: Equatable, Sendable {
    var low: Double
    var high: Double

    init(low: Double, high: Double) {
        self.low = min(low, high)
        self.high = max(low, high)
    }

    init(_ value: Double) {
        self.init(low: value, high: value)
    }
}

struct ProgramSheet: Equatable, Sendable {
    var title: String?
    var blocks: [Block]

    struct Block: Equatable, Sendable {
        var name: String
        var weeks: [Week]
    }

    struct Week: Equatable, Sendable {
        var label: String
        var days: [Day]
    }

    struct Day: Equatable, Sendable {
        var name: String
        var isRest: Bool
        var rows: [Row]
        /// The sheet row the day starts on, 1-based.
        var sourceRow: Int
    }

    enum RestUnit: Equatable, Sendable {
        case seconds
        case minutes
    }

    struct Row: Equatable, Sendable {
        var exerciseName: String
        /// "S1" from "S1: Incline Press": rows sharing a tag on one day are a superset.
        var supersetTag: String?
        var technique: String?
        var warmupSets: ValueRange?
        var workingSets: Int
        var reps: ValueRange?
        /// "10 per leg": the reps count each side.
        var perSide: Bool
        var earlyRPE: ValueRange?
        var lastRPE: ValueRange?
        /// "RIR (Set n)" columns, in set order; nil where the cell is blank, "-" or "N/A".
        var rirPerSet: [Int?]
        var rest: ValueRange?
        var restUnit: RestUnit
        var substitutions: [String]
        var notes: String?
        var linkURL: String?
        /// The sheet row, 1-based.
        var sourceRow: Int
    }
}

/// Why a program file could not be imported. `row` is the 1-based sheet row where there is one.
enum ProgramImportError: Error, Equatable, LocalizedError {
    case unreadableFile
    case noHeaderRow
    case noExercises
    case missingWorkingSets(row: Int)
    case daysDiffer(week: String, row: Int)
    case exercisesDiffer(week: String, day: String, row: Int)
    case unmatchedExercises([String])

    var row: Int? {
        switch self {
        case .missingWorkingSets(let row), .daysDiffer(_, let row), .exercisesDiffer(_, _, let row):
            return row
        case .unreadableFile, .noHeaderRow, .noExercises, .unmatchedExercises:
            return nil
        }
    }

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return String(localized: "This file could not be read as a program.")
        case .noHeaderRow:
            return String(localized: "No header row with an \"Exercise\" column was found.")
        case .noExercises:
            return String(localized: "The file has no exercises.")
        case .missingWorkingSets:
            return String(localized: "Working sets is missing or not a number.")
        case .daysDiffer(let week, _):
            return String(localized: "\(week) has different days from week 1.")
        case .exercisesDiffer(let week, let day, _):
            return String(localized: "\(week), \(day): the exercises differ from week 1.")
        case .unmatchedExercises(let names):
            return String(localized: "Match these exercises first: \(names.joined(separator: ", "))")
        }
    }
}
