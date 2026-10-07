//
//  CSVReader.swift
//  Compound
//
//  RFC 4180 CSV as a grid of text cells: quoted fields, doubled quotes inside them, line breaks
//  inside quotes, and CRLF or LF line endings. An empty field is a nil cell.
//

import Foundation

enum CSVReader {

    static func grid(from data: Data) throws -> SheetGrid {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ProgramImportError.unreadableFile
        }
        return grid(from: text)
    }

    static func grid(from text: String) -> SheetGrid {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var afterQuote = false

        func endField() {
            row.append(field)
            field = ""
            afterQuote = false
        }

        func endRow() {
            endField()
            rows.append(row)
            row = []
        }

        // "\r\n" is one Character in Swift, so a line break is any of the three.
        for character in text.drop(while: { $0 == "\u{FEFF}" }) {
            if inQuotes {
                if character == "\"" {
                    inQuotes = false
                    afterQuote = true
                } else {
                    field.append(character)
                }
                continue
            }
            switch character {
            case "\"":
                // A quote straight after a closing quote is an escaped quote.
                if afterQuote { field.append("\"") }
                inQuotes = true
            case ",":
                endField()
            case "\r\n", "\n", "\r":
                endRow()
            default:
                field.append(character)
            }
        }
        if !field.isEmpty || !row.isEmpty || afterQuote { endRow() }

        return rows.map { fields in
            fields.map { $0.isEmpty ? nil : SheetCell(text: $0) }
        }
    }
}
