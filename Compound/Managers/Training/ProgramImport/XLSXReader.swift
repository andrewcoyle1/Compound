//
//  XLSXReader.swift
//  Compound
//
//  The first sheet of an `.xlsx` as a grid of cells. No dependency: the file is a zip of XML
//  parts (`ZipArchive`, `XMLTreeNode`). Reads shared and inline strings, numbers, dates (a number
//  whose style is a date format), hyperlinks, and merged ranges, whose top-left value is filled
//  into every cell of the range.
//

import Foundation

enum XLSXReader {

    static func grid(from data: Data) throws -> SheetGrid {
        let archive = try ZipArchive(data: data)
        let sheetPath = try firstSheetPath(in: archive)
        guard let sheetData = try archive.entry(sheetPath) else { throw ProgramImportError.unreadableFile }
        let sheet = try XMLTreeNode.parse(sheetData)

        let sharedStrings = try archive.entry("xl/sharedStrings.xml").map(sharedStrings(from:)) ?? []
        let dateStyles = try archive.entry("xl/styles.xml").map(dateStyleIndexes(from:)) ?? []
        let links = try hyperlinks(in: sheet, sheetPath: sheetPath, archive: archive)

        var cells: [CellReference: SheetCell] = [:]
        for cell in sheet.descendants("c") {
            guard let ref = cell.attributes["r"].flatMap(CellReference.init) else { continue }
            var value = Self.value(of: cell, sharedStrings: sharedStrings, dateStyles: dateStyles)
            value?.hyperlink = links[ref]
            if let value { cells[ref] = value }
        }

        for merge in sheet.descendants("mergeCell") {
            let corners = (merge.attributes["ref"] ?? "").split(separator: ":").compactMap { CellReference(String($0)) }
            guard corners.count == 2, let topLeft = cells[corners[0]] else { continue }
            for row in corners[0].row...corners[1].row {
                for column in corners[0].column...corners[1].column {
                    cells[CellReference(row: row, column: column)] = topLeft
                }
            }
        }

        let rowCount = (cells.keys.map(\.row).max() ?? -1) + 1
        let columnCount = (cells.keys.map(\.column).max() ?? -1) + 1
        var grid = SheetGrid(repeating: [SheetCell?](repeating: nil, count: columnCount), count: rowCount)
        for (ref, cell) in cells {
            grid[ref.row][ref.column] = cell
        }
        return grid
    }

    // MARK: - Parts

    /// The workbook's first sheet, through its relationship id.
    private static func firstSheetPath(in archive: ZipArchive) throws -> String {
        guard let workbookData = try archive.entry("xl/workbook.xml"),
              let relsData = try archive.entry("xl/_rels/workbook.xml.rels"),
              let relationshipId = try XMLTreeNode.parse(workbookData).descendants("sheet").first?.attributes["id"],
              let target = try XMLTreeNode.parse(relsData).descendants("Relationship")
                .first(where: { $0.attributes["Id"] == relationshipId })?.attributes["Target"]
        else { throw ProgramImportError.unreadableFile }
        return resolve(target, against: "xl/")
    }

    /// The sheet's hyperlinks by cell. External links are in the sheet's relationships; links
    /// within the workbook carry a `location` instead and are skipped.
    private static func hyperlinks(in sheet: XMLTreeNode, sheetPath: String, archive: ZipArchive) throws -> [CellReference: String] {
        let elements = sheet.descendants("hyperlink")
        guard !elements.isEmpty else { return [:] }
        let folder = sheetPath.split(separator: "/").dropLast().joined(separator: "/")
        let fileName = sheetPath.split(separator: "/").last.map(String.init) ?? ""
        let relsData = try archive.entry("\(folder)/_rels/\(fileName).rels")
        let targets = try relsData.map { data in
            Dictionary(
                try XMLTreeNode.parse(data).descendants("Relationship").compactMap { node in
                    node.attributes["Id"].flatMap { id in node.attributes["Target"].map { (id, $0) } }
                },
                uniquingKeysWith: { first, _ in first }
            )
        } ?? [:]

        var links: [CellReference: String] = [:]
        for element in elements {
            guard let ref = element.attributes["ref"]?.split(separator: ":").first.flatMap({ CellReference(String($0)) }),
                  let target = element.attributes["id"].flatMap({ targets[$0] }) else { continue }
            links[ref] = target
        }
        return links
    }

    /// Each `<si>`'s text, joined across rich-text runs, without phonetic (`rPh`) runs.
    private static func sharedStrings(from data: Data) throws -> [String] {
        try XMLTreeNode.parse(data).children.filter { $0.name == "si" }.map(inlineText)
    }

    private static func inlineText(_ node: XMLTreeNode) -> String {
        node.children.map { child in
            switch child.name {
            case "t": return child.text
            case "r": return child.children.filter { $0.name == "t" }.map(\.text).joined()
            default: return ""
            }
        }.joined()
    }

    /// The `cellXfs` indexes whose number format is a date: built-in ids 14–22, or a custom
    /// format containing d, m or y outside quotes and brackets.
    private static func dateStyleIndexes(from data: Data) throws -> Set<Int> {
        let styles = try XMLTreeNode.parse(data)
        var dateFormats = Set(14...22)
        for format in styles.descendants("numFmt") {
            guard let id = format.attributes["numFmtId"].flatMap(Int.init),
                  let code = format.attributes["formatCode"] else { continue }
            let bare = code.replacing(#/"[^"]*"|\[[^\]]*\]/#, with: "").lowercased()
            if bare.contains(where: { "dmy".contains($0) }) { dateFormats.insert(id) }
        }
        let xfs = styles.child("cellXfs")?.children.filter { $0.name == "xf" } ?? []
        return Set(xfs.indices.filter { index in
            xfs[index].attributes["numFmtId"].flatMap(Int.init).map(dateFormats.contains) ?? false
        })
    }

    // MARK: - Cells

    private static func value(of cell: XMLTreeNode, sharedStrings: [String], dateStyles: Set<Int>) -> SheetCell? {
        let raw = cell.child("v")?.text
        switch cell.attributes["t"] {
        case "s":
            guard let index = raw.flatMap(Int.init), sharedStrings.indices.contains(index) else { return nil }
            return SheetCell(text: sharedStrings[index])
        case "inlineStr":
            return cell.child("is").map { SheetCell(text: inlineText($0)) }
        case "str", "e":
            return raw.map { SheetCell(text: $0) }
        case "b":
            return raw.map { SheetCell(text: $0 == "1" ? "TRUE" : "FALSE") }
        case "d":
            guard let raw else { return nil }
            let date = try? Date(raw, strategy: .iso8601)
            return SheetCell(text: raw, date: date)
        default:
            guard let raw, let number = Double(raw) else { return raw.map { SheetCell(text: $0) } }
            if let style = cell.attributes["s"].flatMap(Int.init), dateStyles.contains(style) {
                let date = Date(timeIntervalSince1970: (number - 25_569) * 86_400)
                return SheetCell(text: date.formatted(.iso8601.year().month().day()), date: date, number: number)
            }
            let text = number == number.rounded() && abs(number) < 1e15 ? String(Int(number)) : String(number)
            return SheetCell(text: text, number: number)
        }
    }

    /// `target` relative to `folder`, or from the archive root when it starts with "/".
    private static func resolve(_ target: String, against folder: String) -> String {
        target.hasPrefix("/") ? String(target.dropFirst()) : folder + target
    }
}

/// "B12" as a 0-based row and column.
private struct CellReference: Hashable {
    let row: Int
    let column: Int

    init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    init?(_ text: String) {
        let letters = text.prefix { $0.isLetter }
        guard !letters.isEmpty, let row = Int(text.dropFirst(letters.count)), row >= 1 else { return nil }
        var column = 0
        for scalar in letters.uppercased().unicodeScalars {
            column = column * 26 + Int(scalar.value) - 64
        }
        self.init(row: row - 1, column: column - 1)
    }
}
