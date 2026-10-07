//
//  ProgramSheetParser+Values.swift
//  Compound
//
//  Reading one cell's value: ranges ("6-8", "~8-9", a cell Excel turned into a date), rest with
//  its unit, the superset prefix, and the blanks a sheet writes as "N/A" or "-".
//

import Foundation

extension ProgramSheetParser {

    /// The cell's text, or nil when it is blank, "-", "–" or "N/A".
    static func text(_ cell: SheetCell?) -> String? {
        guard let text = cell?.text.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return ["-", "–", "—", "n/a", "na"].contains(text.lowercased()) ? nil : text
    }

    /// "6-8", "6–8", "~8-9", "20", "10 per leg" and "1-2 min" as a range. A date cell is the
    /// range Excel turned into it: 8 June is 6–8, month low and day high. So is an ISO date
    /// written as text, which is how a date cell comes out of a CSV export.
    static func range(_ cell: SheetCell?) -> ValueRange? {
        guard let cell else { return nil }
        if let date = cell.date ?? isoDate(cell.text) {
            let parts = utcCalendar.dateComponents([.month, .day], from: date)
            guard let month = parts.month, let day = parts.day else { return nil }
            return ValueRange(low: Double(month), high: Double(day))
        }
        guard let text = text(cell) else { return nil }
        let normalized = text.replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-")
        guard let match = normalized.firstMatch(of: #/^[~≈]?\s*(\d+(?:\.\d+)?)\s*(?:-\s*(\d+(?:\.\d+)?))?/#),
              let low = Double(match.1) else { return nil }
        return ValueRange(low: low, high: match.2.flatMap { Double($0) } ?? low)
    }

    /// "10 per leg", "8 per side", "12 each arm".
    static func isPerSide(_ cell: SheetCell?) -> Bool {
        guard let text = cell?.text.lowercased() else { return false }
        return ["per leg", "per side", "per arm", "each side", "each leg", "each arm"].contains { text.contains($0) }
    }

    /// "1-2 min" is minutes and "30-60 sec" seconds. With no unit, up to 10 reads as minutes.
    static func rest(_ cell: SheetCell?) -> (ValueRange, ProgramSheet.RestUnit)? {
        guard let range = range(cell) else { return nil }
        let text = cell?.text.lowercased() ?? ""
        if text.contains("min") { return (range, .minutes) }
        if text.contains("s") { return (range, .seconds) }
        return (range, range.high <= 10 ? .minutes : .seconds)
    }

    /// "S1: Incline Press" is tag "S1" and name "Incline Press".
    static func supersetTag(_ name: String) -> (tag: String?, name: String) {
        guard let match = name.firstMatch(of: #/^([A-Za-z]{1,2}\d{1,2})\s*:\s*(.+)$/#) else { return (nil, name) }
        return (String(match.1).uppercased(), String(match.2).trimmingCharacters(in: .whitespaces))
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private static func isoDate(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.wholeMatch(of: #/\d{4}-\d{2}-\d{2}/#) != nil else { return nil }
        return try? Date(trimmed, strategy: .iso8601.year().month().day())
    }
}
