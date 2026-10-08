//
//  CSVReaderTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

struct CSVReaderTests {

    private func texts(_ csv: String) -> [[String?]] {
        CSVReader.grid(from: csv).map { $0.map { $0?.text } }
    }

    @Test("Test Plain Fields Split On Commas And Empty Fields Are Nil")
    func testPlainFields() {
        #expect(texts("a,b,,d\n") == [["a", "b", nil, "d"]])
    }

    @Test("Test A Quoted Field Keeps Its Commas And Doubled Quotes")
    func testQuotes() {
        #expect(texts("\"Press, incline\",\"He said \"\"go\"\"\",x") == [["Press, incline", "He said \"go\"", "x"]])
    }

    @Test("Test A Line Break Inside Quotes Stays In The Field")
    func testNewlineInsideQuotes() {
        #expect(texts("\"Pause,\r\nthen drive\",2\r\nnext,3") == [["Pause,\r\nthen drive", "2"], ["next", "3"]])
    }

    @Test("Test CRLF, LF And CR All End A Row, And A Byte Order Mark Is Dropped")
    func testLineEndings() {
        #expect(texts("\u{FEFF}a\r\nb\nc\rd") == [["a"], ["b"], ["c"], ["d"]])
    }

    @Test("Test The Sample Program Reads Row For Row")
    func testFixture() throws {
        let grid = try CSVReader.grid(from: ProgramFixtures.data("sample-program.csv"))
        #expect(grid.count == 49)
        #expect(grid[5][1]?.text == "S1: Incline Press")
        #expect(grid[5][5]?.text == "2025-06-08")
    }
}
