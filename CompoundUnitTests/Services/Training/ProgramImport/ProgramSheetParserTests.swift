//
//  ProgramSheetParserTests.swift
//  CompoundUnitTests
//
//  The sheet rules, read from the fixtures: structure from the first column, columns by header
//  name, and every way a value is written.
//

import Testing
import Foundation
@testable import Compound

struct ProgramSheetParserTests {

    private func row(_ sheet: ProgramSheet, block: Int = 0, week: Int = 0, day: Int = 0, _ index: Int) -> ProgramSheet.Row {
        sheet.blocks[block].weeks[week].days[day].rows[index]
    }

    // MARK: - Structure

    @Test("Test The Title, Blocks, Weeks And Days Come From The First Column", arguments: ["xlsx", "csv"])
    func testStructure(format: String) throws {
        let sheet = format == "xlsx" ? try ProgramFixtures.xlsxSheet() : try ProgramFixtures.csvSheet()
        #expect(sheet.title == "Sample Program")
        #expect(sheet.blocks.map(\.name) == ["Build", "Peak"])
        #expect(sheet.blocks.map { $0.weeks.map(\.label) } == [["Week 1", "Week 2"], ["Week 1", "Week 2"]])
        for block in sheet.blocks {
            for week in block.weeks {
                #expect(week.days.map(\.name) == ["Upper", "Lower", "Rest Day"])
                #expect(week.days.map(\.isRest) == [false, false, true])
            }
        }
    }

    @Test("Test A Day Name Carries Down, Merged Or Not, Until The Next Name")
    func testDayFillDown() throws {
        let sheet = try ProgramFixtures.xlsxSheet()
        // Block 1 merges the day cell over its rows; block 2 writes it on the first row only.
        #expect(sheet.blocks[0].weeks[0].days[0].rows.count == 5)
        #expect(sheet.blocks[1].weeks[0].days[0].rows.count == 4)
        #expect(sheet.blocks[0].weeks[0].days[1].rows.map(\.exerciseName) == ["Squat", "Split Squat", "Leg Curl", "Calf Raise"])
        #expect(sheet.blocks[0].weeks[0].days[0].sourceRow == 6)
    }

    @Test("Test The Same Exercise On Two Rows In A Row Stays Two Rows")
    func testDoubleEntry() throws {
        let sheet = try ProgramFixtures.csvSheet()
        #expect(row(sheet, 2).exerciseName == "Lateral Raise")
        #expect(row(sheet, 3).exerciseName == "Lateral Raise")
        #expect(row(sheet, 3).workingSets == 1)
    }

    @Test("Test A Sheet With No Block Lines Is One Block Named After The Title")
    func testNoBlocks() throws {
        let csv = "My Plan\nDay,Exercise,Working Sets\nWeek 1\nPush,Press,3\nIntro Week\nPush,Press,2\nDeload Week\nPush,Press,1\n"
        let sheet = try ProgramSheetParser.parse(CSVReader.grid(from: csv))
        #expect(sheet.title == "My Plan")
        #expect(sheet.blocks.map(\.name) == ["My Plan"])
        #expect(sheet.blocks[0].weeks.map(\.label) == ["Week 1", "Intro Week", "Deload Week"])
    }

    @Test("Test A Sheet With No Week Lines Is One Week")
    func testNoWeeks() throws {
        let sheet = try ProgramSheetParser.parse(CSVReader.grid(from: "Day,Exercise,Sets\nPush,Press,3\n,Fly,2\n"))
        #expect(sheet.blocks.count == 1)
        #expect(sheet.blocks[0].weeks.count == 1)
        #expect(sheet.blocks[0].weeks[0].days[0].rows.map(\.exerciseName) == ["Press", "Fly"])
    }

    @Test("Test No Header Row Is An Error")
    func testNoHeader() {
        #expect(throws: ProgramImportError.noHeaderRow) {
            try ProgramSheetParser.parse(CSVReader.grid(from: "Week 1\nPush,Press,3\n"))
        }
    }

    @Test("Test A Row Without Working Sets Names Its Row")
    func testMissingWorkingSets() {
        #expect(throws: ProgramImportError.missingWorkingSets(row: 3)) {
            try ProgramSheetParser.parse(CSVReader.grid(from: "Day,Exercise,Working Sets\nWeek 1\nPush,Press,N/A\n"))
        }
    }

    // MARK: - Columns

    @Test("Test Unknown And Set Tracking Columns Are Ignored, Substitutions Kept In Order")
    func testColumns() throws {
        let header: [SheetCell?] = ["Day", "Exercise", "Set 1", "Substitution Option 2", "Rest", "Substitution Option 1", "Coach"]
            .map { SheetCell(text: $0) }
        let columns = try #require(ProgramSheetParser.Columns(header: header))
        #expect(columns.exercise == 1)
        #expect(columns.substitutions == [3, 5])
        #expect(columns.rest == 4)
        #expect(columns.workingSets == nil)
    }

    @Test("Test RIR Columns Are Ordered By Set Number")
    func testRIRColumns() throws {
        let header: [SheetCell?] = ["Exercise", "RIR (Set 2)", "RIR (Set 1)"].map { SheetCell(text: $0) }
        #expect(ProgramSheetParser.Columns(header: header)?.rir == [2, 1])
    }

    // MARK: - Values

    @Test("Test A Date Cell Is A Range Of Month To Day", arguments: ["xlsx", "csv"])
    func testDateCells(format: String) throws {
        let sheet = format == "xlsx" ? try ProgramFixtures.xlsxSheet() : try ProgramFixtures.csvSheet()
        #expect(row(sheet, 0).reps == ValueRange(low: 6, high: 8))
        #expect(row(sheet, 0).warmupSets == ValueRange(low: 2, high: 3))
    }

    @Test("Test Ranges, Single Values And Per Side Reps")
    func testRanges() throws {
        let sheet = try ProgramFixtures.csvSheet()
        #expect(row(sheet, 2).reps == ValueRange(low: 6, high: 8))
        #expect(row(sheet, 3).reps == ValueRange(20))
        #expect(row(sheet, 2).warmupSets == ValueRange(low: 0, high: 1))
        #expect(row(sheet, 4).warmupSets == nil)
        #expect(row(sheet, 0).earlyRPE == ValueRange(low: 7, high: 8))
        #expect(row(sheet, 3).earlyRPE == nil)
        let split = row(sheet, day: 1, 1)
        #expect(split.reps == ValueRange(10))
        #expect(split.perSide)
        #expect(!row(sheet, day: 1, 0).perSide)
        #expect(ProgramSheetParser.range(SheetCell(text: "6–8")) == ValueRange(low: 6, high: 8))
    }

    @Test("Test Rest Keeps Its Unit, And A Dash Is No Rest")
    func testRest() throws {
        let sheet = try ProgramFixtures.csvSheet()
        #expect(row(sheet, 0).rest == nil)
        #expect(row(sheet, 1).rest == ValueRange(low: 1, high: 2))
        #expect(row(sheet, 1).restUnit == .minutes)
        #expect(row(sheet, 2).rest == ValueRange(low: 30, high: 60))
        #expect(row(sheet, 2).restUnit == .seconds)
    }

    @Test("Test A Superset Prefix Is Stripped Into Its Tag")
    func testSupersetTag() throws {
        let sheet = try ProgramFixtures.csvSheet()
        #expect(row(sheet, 0).exerciseName == "Incline Press")
        #expect(row(sheet, 0).supersetTag == "S1")
        #expect(row(sheet, 1).supersetTag == "S1")
        #expect(row(sheet, 2).supersetTag == nil)
    }

    @Test("Test Techniques, Substitutions, Notes And N/A")
    func testTextColumns() throws {
        let sheet = try ProgramFixtures.csvSheet()
        #expect(row(sheet, 0).technique == "Failure")
        #expect(row(sheet, 3).technique == nil)
        #expect(row(sheet, 0).substitutions == ["Machine Press", "DB Press"])
        #expect(row(sheet, 1).substitutions == ["Cable Row"])
        #expect(row(sheet, 0).notes == "Pause at the bottom.")
        #expect(row(sheet, 1).notes == nil)
    }

    @Test("Test Early And Last RPE Columns, Then Per-Set RIR Columns In The Next Block")
    func testEffortColumns() throws {
        let sheet = try ProgramFixtures.csvSheet()
        #expect(row(sheet, 1).lastRPE == ValueRange(9))
        #expect(row(sheet, 1).rirPerSet.isEmpty)
        #expect(row(sheet, block: 1, 0).rirPerSet == [2, 1, 0])
        #expect(row(sheet, block: 1, 2).rirPerSet == [1, 0, nil])
        #expect(row(sheet, block: 1, week: 1, 1).rirPerSet == [2, 1, 0])
        #expect(row(sheet, block: 1, 0).earlyRPE == nil)
    }

    @Test("Test The Exercise Cell's Hyperlink Is The Link")
    func testHyperlink() throws {
        #expect(row(try ProgramFixtures.xlsxSheet(), 0).linkURL == "https://example.com/videos/incline-press")
        #expect(row(try ProgramFixtures.xlsxSheet(), 1).linkURL == nil)
    }

    @Test("Test The Fixtures Read The Same Apart From The Link")
    func testFormatsAgree() throws {
        var xlsx = try ProgramFixtures.xlsxSheet()
        xlsx.blocks[0].weeks[0].days[0].rows[0].linkURL = nil
        #expect(xlsx == (try ProgramFixtures.csvSheet()))
    }
}
