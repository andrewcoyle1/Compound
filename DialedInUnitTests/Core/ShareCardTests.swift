//
//  ShareCardTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
import UIKit
@testable import DialedIn

/// The workout share card: what it says, and that it renders at the size the platforms expect.
@MainActor
struct ShareCardTests {

    private let start = Date(timeIntervalSince1970: 1_780_000_000)
    private let enUS = Locale(identifier: "en_US")

    private func set(reps: Int, weightKg: Double?, isWarmup: Bool = false, side: SetSide? = nil) -> WorkoutSetModel {
        WorkoutSetModel(id: UUID().uuidString, authorId: "me", index: 1, reps: reps, weightKg: weightKg, side: side, isWarmup: isWarmup, completedAt: start, dateCreated: start)
    }

    private func session(name: String = "Push Day", minutes: Double = 65, streak: Int? = nil, sets: [WorkoutSetModel]) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: "s1",
            authorId: "me",
            name: name,
            dateCreated: start,
            endedAt: start.addingTimeInterval(minutes * 60),
            exercises: [WorkoutExerciseModel(id: "e1", authorId: "me", templateId: "bench", name: "Bench", trackingMode: .weightReps, index: 1, sets: sets)],
            streakCount: streak
        )
    }

    private func content(
        _ session: WorkoutSessionModel,
        author: UserModel? = UserModel(userId: "me", submittedFirstName: "Alex"),
        records: [WorkoutSessionHighlights.PersonalRecord] = [],
        weekly: Int = 1
    ) -> ShareCardContent {
        ShareCardContent.make(session: session, author: author, personalRecords: records, weeklyWorkoutNumber: weekly, locale: enUS)
    }

    // MARK: - Derived strings

    @Test("Test Duration Reads Hours And Minutes")
    func testDurationReadsHoursAndMinutes() {
        #expect(ShareCardContent.durationText(from: start, to: start.addingTimeInterval(65 * 60)) == "1h 5m")
        #expect(ShareCardContent.durationText(from: start, to: start.addingTimeInterval(45 * 60)) == "45m")
        #expect(ShareCardContent.durationText(from: start, to: nil) == nil)
    }

    @Test("Test Volume Is Grouped And Absent When Nothing Was Lifted")
    func testVolumeIsGroupedAndAbsentWhenNothingWasLifted() {
        #expect(ShareCardContent.volumeText(12_340, locale: enUS) == "12,340 kg")
        #expect(ShareCardContent.volumeText(0, locale: enUS) == nil)
    }

    @Test("Test Warm Ups Are Left Out Of Volume And Sets")
    func testWarmUpsAreLeftOutOfVolumeAndSets() {
        let card = content(session(sets: [
            set(reps: 10, weightKg: 60, isWarmup: true),
            set(reps: 5, weightKg: 100),
            set(reps: 5, weightKg: 100)
        ]))

        #expect(card.volumeText == "1,000 kg")
        #expect(card.setCount == 2)
        #expect(card.durationText == "1h 5m")
        #expect(card.sessionName == "Push Day")
    }

    @Test("Test A Left And Right Count As One Set")
    func testALeftAndRightCountAsOneSet() {
        let card = content(session(sets: [set(reps: 8, weightKg: 20, side: .left), set(reps: 8, weightKg: 20, side: .right)]))

        #expect(card.setCount == 1)
    }

    @Test("Test Records Weekly Count And Streak Read As On The Feed")
    func testRecordsWeeklyCountAndStreakReadAsOnTheFeed() {
        let card = content(
            session(streak: 12, sets: [set(reps: 5, weightKg: 100)]),
            records: [.init(exerciseName: "Bench", detail: "100 kg × 5")],
            weekly: 3
        )

        #expect(card.personalRecordLines == ["Bench 100 kg × 5"])
        #expect(card.weeklyText == "3rd workout of the week")
        #expect(card.streakText == "12-day streak")
    }

    @Test("Test A First Workout With No Records Has No Highlights")
    func testAFirstWorkoutWithNoRecordsHasNoHighlights() {
        let card = content(session(sets: [set(reps: 5, weightKg: 100)]))

        #expect(card.personalRecordLines.isEmpty)
        #expect(card.weeklyText == nil)
        #expect(card.streakText == nil)
    }

    @Test("Test Records Come From The Author's History")
    func testRecordsComeFromTheAuthorsHistory() {
        let earlier = WorkoutSessionModel(
            id: "s0",
            authorId: "me",
            name: "Push Day",
            dateCreated: start.addingTimeInterval(-86_400 * 7),
            endedAt: start.addingTimeInterval(-86_400 * 7 + 3600),
            exercises: [WorkoutExerciseModel(id: "e0", authorId: "me", templateId: "bench", name: "Bench", trackingMode: .weightReps, index: 1, sets: [set(reps: 5, weightKg: 90)])]
        )
        let now = session(sets: [set(reps: 5, weightKg: 100)])

        let card = ShareCardContent.make(session: now, author: nil, history: [earlier, now], locale: enUS)

        #expect(card.personalRecordLines == ["Bench 100 kg × 5"])
    }

    /// The card names only the author, and only by first name.
    @Test("Test The Card Never Carries A Last Name Or Display Name")
    func testTheCardNeverCarriesALastNameOrDisplayName() {
        let author = UserModel(userId: "me", displayName: "alex_lifts", firstName: "Alex", lastName: "Smithers")
        let card = content(session(sets: [set(reps: 5, weightKg: 100)]), author: author)
        let printed = [card.firstName, card.sessionName, card.dateText, card.durationText, card.volumeText, card.weeklyText, card.streakText]
            .compactMap { $0 } + card.personalRecordLines

        #expect(card.firstName == "Alex")
        #expect(!printed.contains { $0.contains("Smithers") || $0.contains("alex_lifts") })
    }

    // MARK: - Renderer

    @Test("Test Renders At Pixel Size For Each Format", arguments: [
        (WorkoutShareCardView.Format.story, 1080, 1920),
        (WorkoutShareCardView.Format.square, 1080, 1080)
    ])
    func testRendersAtPixelSizeForEachFormat(format: WorkoutShareCardView.Format, width: Int, height: Int) throws {
        let longName = String(repeating: "Upper Body Hypertrophy Session ", count: 4)
        let card = content(
            session(name: longName, streak: 5, sets: [set(reps: 5, weightKg: 100)]),
            records: [.init(exerciseName: "Bench", detail: "100 kg × 5")],
            weekly: 2
        )

        let image = try #require(ShareCardRenderer.render(card, avatar: nil, format: format))
        let cgImage = try #require(image.cgImage)

        #expect(cgImage.width == width)
        #expect(cgImage.height == height)
    }
}
