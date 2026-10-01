//
//  NutrientMapTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The nutrient snapshot every food, meal and daily total is made of.
///
/// Two operations carry the weight: scaling, because nutrients are stored per 100g and a portion is
/// any other amount, and addition, because a plate is the sum of its foods and a day the sum of its
/// plates. An error in either is wrong on every calorie the app shows.
@MainActor
struct NutrientMapTests {

    private let oats: NutrientMap = [.calories: 379, .protein: 13.2, .carbs: 67.7, .fatTotal: 6.5, .fiber: 10.1]

    // MARK: - Reading

    @Test("Test Reading A Recorded Nutrient")
    func testReadingARecordedNutrient() {
        #expect(oats[.calories] == 379)
        #expect(oats[.protein] == 13.2)
    }

    /// Absent means "this food's data does not record it", which is not the same as zero — and the
    /// subscript says so by answering nil.
    @Test("Test An Unrecorded Nutrient Is Absent, Not Zero")
    func testAnUnrecordedNutrientIsAbsentNotZero() {
        #expect(oats[.sodiumMg] == nil)
        #expect(oats[.sodiumMg, default: 0] == 0)
    }

    @Test("Test An Empty Map Records Nothing")
    func testAnEmptyMapRecordsNothing() {
        let empty = NutrientMap()

        #expect(empty[.calories] == nil)
        #expect(Array(empty).isEmpty)
    }

    @Test("Test Writing A Nutrient")
    func testWritingANutrient() {
        var map = NutrientMap()
        map[.calories] = 100

        #expect(map[.calories] == 100)
    }

    // MARK: - Scaling a portion

    /// Callers pass `amount / 100`, since the stored values are per 100g.
    @Test("Test Scaling A Portion")
    func testScalingAPortion() {
        let half = oats.scaled(by: 0.5)

        #expect(half[.calories] == 189.5)
        #expect(half[.protein] == 6.6)
    }

    @Test("Test Scaling By One Changes Nothing")
    func testScalingByOneChangesNothing() {
        let same = oats.scaled(by: 1)

        #expect(same[.calories] == oats[.calories])
        #expect(same[.fiber] == oats[.fiber])
    }

    @Test("Test Scaling To Nothing Gives Zeroes, Not Absences")
    func testScalingToNothingGivesZeroesNotAbsences() {
        let none = oats.scaled(by: 0)

        // Still recorded, just zero: the food is known to contain these, in a zero-gram portion.
        #expect(none[.calories] == 0)
        #expect(none[.sodiumMg] == nil)
    }

    @Test("Test Scaling Up")
    func testScalingUp() {
        let double = oats.scaled(by: 2)

        #expect(double[.calories] == 758)
    }

    @Test("Test Scaling Leaves Unrecorded Nutrients Unrecorded")
    func testScalingLeavesUnrecordedNutrientsUnrecorded() {
        #expect(oats.scaled(by: 3)[.sodiumMg] == nil)
    }

    @Test("Test Mapping Every Value")
    func testMappingEveryValue() {
        let rounded = oats.mapValues { $0.rounded() }

        #expect(rounded[.protein] == 13)
        #expect(rounded[.carbs] == 68)
    }

    // MARK: - Totalling a plate

    @Test("Test Adding Two Foods Sums Their Nutrients")
    func testAddingTwoFoodsSumsTheirNutrients() {
        let milk: NutrientMap = [.calories: 61, .protein: 3.2, .carbs: 4.8, .fatTotal: 3.3]
        let total = oats + milk

        #expect(total[.calories] == 440)
        #expect(abs((total[.protein] ?? 0) - 16.4) < 0.0001)
    }

    /// A nutrient only one food records is carried through rather than dropped: for a total there
    /// is nothing better to do than add what is known.
    @Test("Test A Nutrient Only One Food Records Is Kept")
    func testANutrientOnlyOneFoodRecordsIsKept() {
        let milk: NutrientMap = [.calories: 61, .calciumMg: 120]
        let total = oats + milk

        #expect(total[.fiber] == 10.1)
        #expect(total[.calciumMg] == 120)
    }

    @Test("Test Adding Nothing Changes Nothing")
    func testAddingNothingChangesNothing() {
        let total = oats + NutrientMap()

        #expect(total[.calories] == oats[.calories])
        #expect(Array(total).count == Array(oats).count)
    }

    @Test("Test Adding In Place")
    func testAddingInPlace() {
        var running = NutrientMap()

        running += oats
        running += [.calories: 61]

        #expect(running[.calories] == 440)
    }

    /// Order must not matter, or a day's total would depend on the order meals were logged in.
    @Test("Test Adding Is Commutative")
    func testAddingIsCommutative() {
        let milk: NutrientMap = [.calories: 61, .protein: 3.2, .calciumMg: 120]

        let oneWay = oats + milk
        let theOther = milk + oats

        for key in NutrientKey.allCases {
            #expect(oneWay[key] == theOther[key])
        }
    }

    /// A whole day, built the way the app builds it: each food scaled to its portion, then summed.
    @Test("Test A Day Of Meals Totals Up")
    func testADayOfMealsTotalsUp() {
        let servingOfOats = oats.scaled(by: 0.5)      // 50 g
        let glassOfMilk = NutrientMap([.calories: 61, .protein: 3.2]).scaled(by: 2.5) // 250 ml

        let day = servingOfOats + glassOfMilk

        #expect(day[.calories] == 189.5 + 152.5)
        #expect(abs((day[.protein] ?? 0) - (6.6 + 8.0)) < 0.0001)
    }

    // MARK: - Breakdowns

    @Test("Test Recorded Keys Only List What Is There")
    func testRecordedKeysOnlyListWhatIsThere() {
        let recorded = oats.recordedKeys(in: .carbs)

        #expect(recorded.contains(.fiber))
        #expect(!recorded.contains(.sugar))
    }

    @Test("Test An Empty Map Has No Recorded Keys")
    func testAnEmptyMapHasNoRecordedKeys() {
        for category in Macros.allCases {
            #expect(NutrientMap().recordedKeys(in: category).isEmpty)
        }
    }

    // MARK: - Codable

    /// Stored as a plain `[String: Double]` keyed by raw value, so the round trip is what keeps a
    /// saved food readable.
    @Test("Test A Nutrient Map Round Trips")
    func testANutrientMapRoundTrips() throws {
        let data = try JSONEncoder().encode(oats)
        let decoded = try JSONDecoder().decode(NutrientMap.self, from: data)

        for key in NutrientKey.allCases {
            #expect(decoded[key] == oats[key])
        }
    }

    @Test("Test A Nutrient Map Encodes As Its Raw Keys")
    func testANutrientMapEncodesAsItsRawKeys() throws {
        let data = try JSONEncoder().encode(oats)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Double]

        #expect(json?["calories"] == 379)
        #expect(json?["fat_total"] == 6.5)
    }

    /// A key the app no longer knows is skipped rather than failing the whole food — an older
    /// document with a retired nutrient still decodes.
    @Test("Test An Unknown Nutrient Is Skipped")
    func testAnUnknownNutrientIsSkipped() throws {
        let data = try JSONSerialization.data(withJSONObject: ["calories": 100.0, "unobtainium_mg": 5.0])
        let decoded = try JSONDecoder().decode(NutrientMap.self, from: data)

        #expect(decoded[.calories] == 100)
        #expect(Array(decoded).count == 1)
    }

    // MARK: - Stored bad data

    /// Firestore hands non-finite doubles back verbatim, so the JSON stand-in has to be told to
    /// read them too — by default `JSONDecoder` refuses the document outright and the hole this
    /// covers would never be reached.
    private var lenientDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "inf",
            negativeInfinity: "-inf",
            nan: "nan"
        )
        return decoder
    }

    /// A meal written by a build predating the input sanitising can carry a NaN, and around fifteen
    /// screens print nutrients through `Int(_:)`, which traps on one while drawing.
    @Test("Test A Stored NaN Nutrient Is Dropped")
    func testAStoredNaNNutrientIsDropped() throws {
        let json = Data(#"{"calories":"nan","protein":13.2}"#.utf8)

        let decoded = try lenientDecoder.decode(NutrientMap.self, from: json)

        #expect(decoded[.calories] == nil)
        #expect(decoded[.protein] == 13.2)
    }

    @Test("Test A Stored Infinite Nutrient Is Dropped")
    func testAStoredInfiniteNutrientIsDropped() throws {
        let json = Data(#"{"calories":"inf","fiber":"-inf","protein":13.2}"#.utf8)

        let decoded = try lenientDecoder.decode(NutrientMap.self, from: json)

        #expect(decoded[.calories] == nil)
        #expect(decoded[.fiber] == nil)
        #expect(decoded[.protein] == 13.2)
    }

    /// Dropped, not zeroed: absent means "not recorded", which is what a corrupt figure amounts to,
    /// while a zero would assert the food contains none of the nutrient and put a `0` row in the
    /// breakdown.
    @Test("Test A Dropped Nutrient Is Absent Rather Than Zero")
    func testADroppedNutrientIsAbsentRatherThanZero() throws {
        let json = Data(#"{"selenium_mcg":"nan"}"#.utf8)

        let decoded = try lenientDecoder.decode(NutrientMap.self, from: json)

        #expect(decoded[.seleniumMcg] == nil)
        #expect(decoded.recordedKeys(in: .minerals).isEmpty)
    }

    /// Only the bad figure goes; the rest of the food is still the food it was.
    @Test("Test The Rest Of A Document Survives A Bad Nutrient")
    func testTheRestOfADocumentSurvivesABadNutrient() throws {
        let json = Data(#"{"calories":379,"protein":"nan","carbs":67.7,"fat_total":6.5,"fiber":10.1}"#.utf8)

        let decoded = try lenientDecoder.decode(NutrientMap.self, from: json)

        #expect(decoded[.protein] == nil)
        #expect(Array(decoded).count == 4)
        for key in [NutrientKey.calories, .carbs, .fatTotal, .fiber] {
            #expect(decoded[key] == oats[key])
        }
    }

    /// Every ordinary food must decode exactly as before, zeroes and all.
    @Test("Test A Well Formed Document Is Untouched")
    func testAWellFormedDocumentIsUntouched() throws {
        let stored: NutrientMap = [.calories: 0, .protein: 13.2, .sodiumMg: -1]
        let data = try JSONEncoder().encode(stored)

        let decoded = try lenientDecoder.decode(NutrientMap.self, from: data)

        #expect(decoded == stored)
        #expect(decoded[.calories] == 0)
        #expect(decoded[.sodiumMg] == -1)
    }

    /// A NaN reaching the encoder fails the whole document rather than the one figure, so it is
    /// dropped on the way out as well as on the way in.
    @Test("Test A Non Finite Nutrient Is Not Written Back Out")
    func testANonFiniteNutrientIsNotWrittenBackOut() throws {
        let corrupt: NutrientMap = [.calories: .nan, .protein: .infinity, .carbs: 67.7]

        let data = try JSONEncoder().encode(corrupt)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Double]

        #expect(json?.keys.sorted() == ["carbs"])
        #expect(json?["carbs"] == 67.7)
    }

    // MARK: - Macro keys

    /// The four headline macros map to the nutrients the rings and charts read.
    @Test("Test Each Macro Points At Its Nutrient")
    func testEachMacroPointsAtItsNutrient() {
        #expect(Macro.cals.nutrientKey == .calories)
        #expect(Macro.protein.nutrientKey == .protein)
        #expect(Macro.carbs.nutrientKey == .carbs)
        #expect(Macro.fat.nutrientKey == .fatTotal)
    }

    @Test("Test Every Macro Has A Title And An Icon")
    func testEveryMacroHasATitleAndAnIcon() {
        for macro in Macro.allCases {
            #expect(!macro.title.isEmpty)
            #expect(!macro.iconName.isEmpty)
        }
    }

    /// Persisted by raw value alongside the nutrients themselves.
    @Test("Test Nutrient Key Raw Values")
    func testNutrientKeyRawValues() {
        #expect(NutrientKey.calories.rawValue == "calories")
        #expect(NutrientKey.protein.rawValue == "protein")
        #expect(NutrientKey.carbs.rawValue == "carbs")
        #expect(NutrientKey.fatTotal.rawValue == "fat_total")
        #expect(NutrientKey.fatSaturated.rawValue == "fat_saturated")
        #expect(NutrientKey.fiber.rawValue == "fiber")
        #expect(NutrientKey.sugar.rawValue == "sugar")
        #expect(NutrientKey.sodiumMg.rawValue == "sodium_mg")
    }

    @Test("Test Nutrient Keys Are Unique")
    func testNutrientKeysAreUnique() {
        let raws = NutrientKey.allCases.map(\.rawValue)

        #expect(Set(raws).count == raws.count)
    }

    @Test("Test Every Nutrient Has A Name And A Unit")
    func testEveryNutrientHasANameAndAUnit() {
        for key in NutrientKey.allCases {
            #expect(!key.name.isEmpty)
            #expect(!key.unit.isEmpty)
        }
    }
}
