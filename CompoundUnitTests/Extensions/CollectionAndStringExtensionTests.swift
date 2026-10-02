//
//  CollectionAndStringExtensionTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The small collection and string helpers used across the app. Each is a handful of lines, and
/// each has an edge — an empty collection, a limit larger than the collection, a conflict between
/// two dictionaries — where the behaviour is a choice rather than an obvious answer.
@MainActor
struct CollectionExtensionTests {

    private struct Item: Equatable {
        let name: String
        let count: Int
    }

    private let items = [
        Item(name: "Charlie", count: 2),
        Item(name: "Alice", count: 3),
        Item(name: "Bob", count: 1)
    ]

    // MARK: - Sorting by key path

    @Test("Test Sorting By A Key Path")
    func testSortingByAKeyPath() {
        #expect(items.sortedByKeyPath(keyPath: \.name).map(\.name) == ["Alice", "Bob", "Charlie"])
        #expect(items.sortedByKeyPath(keyPath: \.count).map(\.count) == [1, 2, 3])
    }

    @Test("Test Sorting Descending")
    func testSortingDescending() {
        #expect(items.sortedByKeyPath(keyPath: \.count, ascending: false).map(\.count) == [3, 2, 1])
    }

    /// The mutating and returning forms share a name, so the call has to say which it wants.
    @Test("Test Sorting In Place")
    func testSortingInPlace() {
        var sorted = items
        sorted.sortedByKeyPath(keyPath: \.name, ascending: true) as Void

        #expect(sorted.map(\.name) == ["Alice", "Bob", "Charlie"])
    }

    @Test("Test Sorting An Empty Array")
    func testSortingAnEmptyArray() {
        #expect([Item]().sortedByKeyPath(keyPath: \.name).isEmpty)
    }

    // MARK: - Taking a few

    @Test("Test Taking The First Few")
    func testTakingTheFirstFew() {
        #expect(items.first(upTo: 2)?.map(\.name) == ["Charlie", "Alice"])
    }

    /// Asking for more than there is gives everything rather than nothing or a crash.
    @Test("Test Taking More Than There Is")
    func testTakingMoreThanThereIs() {
        #expect(items.first(upTo: 99)?.count == 3)
        #expect(items.last(upTo: 99)?.count == 3)
    }

    @Test("Test Taking The Last Few")
    func testTakingTheLastFew() {
        #expect(items.last(upTo: 2)?.map(\.name) == ["Alice", "Bob"])
    }

    /// Nil rather than an empty array, which is what lets a caller show "nothing yet" instead of an
    /// empty row.
    @Test("Test Taking From An Empty Collection Gives Nil")
    func testTakingFromAnEmptyCollectionGivesNil() {
        #expect([Item]().first(upTo: 3) == nil)
        #expect([Item]().last(upTo: 3) == nil)
    }

    @Test("Test Taking None")
    func testTakingNone() {
        #expect(items.first(upTo: 0)?.isEmpty == true)
    }

    // MARK: - Dictionaries

    @Test("Test Merging Keeps The Existing Value By Default")
    func testMergingKeepsTheExistingValueByDefault() {
        var existing = ["a": 1, "b": 2]
        existing.merge(["b": 99, "c": 3])

        #expect(existing == ["a": 1, "b": 2, "c": 3])
    }

    @Test("Test Merging Can Prefer The New Value")
    func testMergingCanPreferTheNewValue() {
        var existing = ["a": 1, "b": 2]
        existing.merge(["b": 99], conflictTakeExisting: false)

        #expect(existing["b"] == 99)
    }

    @Test("Test Merging Nothing Changes Nothing")
    func testMergingNothingChangesNothing() {
        var existing = ["a": 1]
        existing.merge(nil)

        #expect(existing == ["a": 1])
    }

    @Test("Test Trimming A Dictionary To A Few Keys")
    func testTrimmingADictionaryToAFewKeys() {
        var values = ["a": 1, "b": 2, "c": 3, "d": 4]
        values.first(upTo: 2)

        #expect(values.count == 2)
    }
}

/// The string helpers, including the one that flattens analytics parameters.
@MainActor
struct StringExtensionTests {

    @Test("Test Clipping To A Maximum Length")
    func testClippingToAMaximumLength() {
        #expect("Bench Press".clipped(maxCharacters: 5) == "Bench")
        #expect("Bench".clipped(maxCharacters: 99) == "Bench")
        #expect("Bench".clipped(maxCharacters: 0) == "")
    }

    @Test("Test Replacing Spaces With Underscores")
    func testReplacingSpacesWithUnderscores() {
        #expect("Barbell Bench Press".replaceSpacesWithUnderscores() == "Barbell_Bench_Press")
        #expect("Squat".replaceSpacesWithUnderscores() == "Squat")
        #expect("".replaceSpacesWithUnderscores() == "")
    }

    // MARK: - Converting analytics values

    @Test("Test Converting Simple Values To Strings")
    func testConvertingSimpleValuesToStrings() {
        #expect(String.convertToString("already a string") == "already a string")
        #expect(String.convertToString(42) == "42")
        #expect(String.convertToString(true) == "true")
        #expect(String.convertToString(3.5) == "3.5")
    }

    /// Arrays are sorted before joining, so the same set of values logs the same string whatever
    /// order it arrived in — otherwise one analytics event would look like several.
    @Test("Test Converting An Array Sorts It")
    func testConvertingAnArraySortsIt() {
        #expect(String.convertToString(["c", "a", "b"]) == "a, b, c")
        #expect(String.convertToString([3, 1, 2]) == "1, 2, 3")
    }

    @Test("Test Converting An Empty Array")
    func testConvertingAnEmptyArray() {
        #expect(String.convertToString([String]()) == "")
    }

    // MARK: - Stable hashing

    /// Swift's own `hashValue` is seeded per launch. This one is not, which is why it can be used
    /// for anything remembered between launches.
    @Test("Test The Stable Hash Is The Same Every Time")
    func testTheStableHashIsTheSameEveryTime() {
        #expect("bench press".stableHashValue == "bench press".stableHashValue)
        #expect("bench press".stableHashValue != "squat".stableHashValue)
        #expect("".stableHashValue == 5381)
    }
}

/// The name check on anything a user types and other people see.
@MainActor
struct TextValidationTests {

    @Test("Test A Long Enough Name Is Accepted")
    func testALongEnoughNameIsAccepted() throws {
        try TextValidationHelper.checkIfTextIsValid(text: "Bench Press")
    }

    @Test("Test A Short Name Is Rejected")
    func testAShortNameIsRejected() {
        #expect(throws: TextValidationHelper.TextValidationError.self) {
            try TextValidationHelper.checkIfTextIsValid(text: "abc")
        }
        #expect(throws: TextValidationHelper.TextValidationError.self) {
            try TextValidationHelper.checkIfTextIsValid(text: "")
        }
    }

    @Test("Test The Minimum Length Can Be Changed")
    func testTheMinimumLengthCanBeChanged() throws {
        try TextValidationHelper.checkIfTextIsValid(text: "ab", minimumCharacterCount: 2)

        #expect(throws: TextValidationHelper.TextValidationError.self) {
            try TextValidationHelper.checkIfTextIsValid(text: "ab", minimumCharacterCount: 3)
        }
    }

    @Test("Test Bad Words Are Rejected Whatever Their Case")
    func testBadWordsAreRejectedWhateverTheirCase() {
        #expect(throws: TextValidationHelper.TextValidationError.self) {
            try TextValidationHelper.checkIfTextIsValid(text: "shit")
        }
        #expect(throws: TextValidationHelper.TextValidationError.self) {
            try TextValidationHelper.checkIfTextIsValid(text: "SHIT")
        }
    }

    /// The list is matched against the whole string, so a word that merely contains one gets
    /// through. Pinned as it stands rather than as it might ideally be.
    @Test("Test A Bad Word Inside A Longer Name Is Allowed")
    func testABadWordInsideALongerNameIsAllowed() throws {
        try TextValidationHelper.checkIfTextIsValid(text: "assisted pull up")
    }
}
