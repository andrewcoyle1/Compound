//
//  ExerciseImageViewTests.swift
//  DialedInUnitTests
//

import Testing
@testable import DialedIn

@MainActor
struct ExerciseImageViewTests {

    @Test func initialsTakeTheFirstLetterOfAtMostTwoWords() {
        #expect(ExerciseImageView.initials(of: "Barbell Bench Press") == "BB")
        #expect(ExerciseImageView.initials(of: "plank") == "P")
        #expect(ExerciseImageView.initials(of: "  Pull  Up ") == "PU")
        #expect(ExerciseImageView.initials(of: "") == "")
    }
}
