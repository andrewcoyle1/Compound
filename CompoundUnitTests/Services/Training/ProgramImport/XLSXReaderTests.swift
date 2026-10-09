//
//  XLSXReaderTests.swift
//  CompoundUnitTests
//
//  Reading the first sheet of an `.xlsx` with no dependency. sample-program.xlsx is openpyxl's
//  output (inline strings, deflated entries, real date cells, a hyperlink, merged day cells);
//  shared-stored.xlsx is hand-written with shared strings and stored entries.
//

import Testing
import Foundation
@testable import Compound

struct XLSXReaderTests {

    private func sample() throws -> SheetGrid {
        try XLSXReader.grid(from: ProgramFixtures.data("sample-program.xlsx"))
    }

    private func cell(_ grid: SheetGrid, _ ref: String) -> SheetCell? {
        let column = Int(ref.unicodeScalars.first?.value ?? 65) - 65
        let row = (Int(ref.dropFirst()) ?? 1) - 1
        guard grid.indices.contains(row), grid[row].indices.contains(column) else { return nil }
        return grid[row][column]
    }

    @Test("Test Inline Strings From A Deflated Sheet Read As Text")
    func testInlineStringsFromADeflatedSheet() throws {
        let grid = try sample()
        #expect(cell(grid, "A1")?.text == "Sample Program")
        #expect(cell(grid, "B4")?.text == "Exercise")
        #expect(cell(grid, "B6")?.text == "S1: Incline Press")
    }

    @Test("Test Shared Strings From A Stored Sheet Join Rich Runs And Skip Phonetic Runs")
    func testSharedStringsFromAStoredSheet() throws {
        let grid = try XLSXReader.grid(from: ProgramFixtures.data("shared-stored.xlsx"))
        #expect(cell(grid, "A1")?.text == "Exercise")
        #expect(cell(grid, "C1")?.text == "Working Sets")
        #expect(cell(grid, "A2")?.text == "Leg Curl & Raise ")
        #expect(cell(grid, "C2")?.number == 3)
        #expect(cell(grid, "D2")?.text == "inline")
        #expect(cell(grid, "B1") == nil)
    }

    @Test("Test A Number Cell Carries Its Value And Integral Text")
    func testNumbers() throws {
        let grid = try sample()
        #expect(cell(grid, "E6")?.number == 2)
        #expect(cell(grid, "E6")?.text == "2")
        #expect(cell(grid, "E6")?.date == nil)
    }

    @Test("Test A Number In A Date Format Reads As The Date From The 1900 Serial")
    func testDates() throws {
        let grid = try sample()
        let reps = try #require(cell(grid, "F6"))
        let warmups = try #require(cell(grid, "D6"))
        #expect(reps.text == "2025-06-08")
        #expect(warmups.text == "2025-02-03")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let parts = calendar.dateComponents([.year, .month, .day], from: try #require(reps.date))
        #expect(parts.year == 2025 && parts.month == 6 && parts.day == 8)
    }

    @Test("Test A Hyperlink Lands On Its Cell Through The Sheet's Relationships")
    func testHyperlinks() throws {
        let grid = try sample()
        #expect(cell(grid, "B6")?.hyperlink == "https://example.com/videos/incline-press")
        #expect(cell(grid, "B7")?.hyperlink == nil)
    }

    @Test("Test A Merged Range Fills Every Cell With Its Top-Left Value")
    func testMergedCellsFillDown() throws {
        let grid = try sample()
        for row in 6...10 {
            #expect(cell(grid, "A\(row)")?.text == "Upper")
        }
        #expect(cell(grid, "A11")?.text == "Lower")
    }

    @Test("Test A File That Is Not A Zip Is Unreadable")
    func testNotAZip() {
        #expect(throws: ProgramImportError.unreadableFile) {
            try XLSXReader.grid(from: Data("Exercise,Sets".utf8))
        }
    }
}
