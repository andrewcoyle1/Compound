//
//  SetTable.swift
//  Compound
//
//  The set table's shared measures: its column widths, the column frame the rows and headings
//  both use, its rows' insets, and the width each field's column takes.
//

import SwiftUI

enum SetTable {
    /// The set number and Done are the 44 pt minimum hit area; Last gave up the room they needed.
    static let setColumnWidth = ControlSize.row
    static let previousColumnWidth: CGFloat = 78
    static let doneColumnWidth = ControlSize.row
    /// A weight or distance, and the time beside a distance.
    static let fieldColumnWidth: CGFloat = 70
    static let repsColumnWidth: CGFloat = 50
    /// A timed set's own time, with room for its stopwatch.
    static let timeColumnWidth: CGFloat = 90
    /// A row's cell height at the default text size, scaled so a larger size never clips a value.
    static let cellHeight: CGFloat = 35
}

extension View {
    /// A column of the set table: its fixed width, or on the stacked row at accessibility sizes a
    /// share of the line that grows with the text.
    @ViewBuilder
    func setColumn(width: CGFloat, height: CGFloat? = nil, stretches: Bool, alignment: Alignment = .center) -> some View {
        if stretches {
            frame(maxWidth: .infinity, minHeight: height, alignment: alignment)
        } else {
            frame(width: width, height: height, alignment: .center)
        }
    }

    /// A row of the set table: no separator, and running to the card's edge.
    func setTableRow() -> some View {
        listRowSeparator(.hidden)
            .listRowInsets(.vertical, 0)
            .listRowInsets(.leading, 0)
    }
}

extension SetKeyboardField {

    /// The field's column, shared with its heading. A time on its own is wider, to hold its
    /// stopwatch.
    func columnWidth(in fields: [Self]) -> CGFloat {
        switch self {
        case .weight, .distance: SetTable.fieldColumnWidth
        case .reps: SetTable.repsColumnWidth
        case .duration: usesStopwatch(in: fields) ? SetTable.timeColumnWidth : SetTable.fieldColumnWidth
        }
    }

    /// A time on its own is timed with a stopwatch; beside a distance it is typed.
    func usesStopwatch(in fields: [Self]) -> Bool {
        self == .duration && !fields.contains(.distance)
    }

    /// What VoiceOver calls the field, after the row's name: "Set 2, Weight, kilograms".
    func accessibilityName(units: ExerciseUnitPreference) -> String {
        switch self {
        case .weight: String(localized: "Weight, \(units.weightUnit.displayName)")
        case .reps: String(localized: "Reps")
        case .distance: String(localized: "Distance, \(units.distanceUnit.displayName)")
        case .duration: String(localized: "Time, minutes and seconds")
        }
    }
}
