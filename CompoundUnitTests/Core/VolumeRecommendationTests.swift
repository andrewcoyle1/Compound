//
//  VolumeRecommendationTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The per-muscle volume suggestion: which way it points for each combination of strength trend,
/// effort and adherence, the size of the step, and the floors it never goes under.
@MainActor
struct VolumeRecommendationTests {

    private func inputs(
        weeks: [Double] = [12, 12, 12, 12],
        trend: Double? = 0,
        adherence: Double? = 1,
        rpeDrift: Double? = 0,
        age: Int? = 30
    ) -> VolumeRecommendation.Inputs {
        VolumeRecommendation.Inputs(weeklySets: weeks, trendPercentPerWeek: trend, adherence: adherence, rpeDrift: rpeDrift, age: age)
    }

    // MARK: - The rule

    @Test("Test Flat Strength With Steady Effort Adds Ten To Twenty Percent")
    func testFlatStrengthAdds() {
        let result = VolumeRecommendation.recommend(inputs(trend: 0.2))
        #expect(result.action == .add)
        #expect(result.baselineSets == 12)
        // 12 × 1.1 = 13.2 → 13; 12 × 1.2 = 14.4 → 14.
        #expect(result.suggestedSets == 13...14)
    }

    /// At a low baseline 10% is less than a set, so the step is at least one whole set.
    @Test("Test The Step Up Is At Least One Set")
    func testTheStepUpIsAtLeastOneSet() {
        let result = VolumeRecommendation.recommend(inputs(weeks: [5, 5, 5, 5]))
        #expect(result.action == .add)
        #expect(result.suggestedSets == 6...6)
    }

    @Test("Test Rising Strength Keeps The Current Volume")
    func testRisingStrengthKeeps() {
        let result = VolumeRecommendation.recommend(inputs(trend: 1.5))
        #expect(result.action == .keep)
        #expect(result.suggestedSets == 12...12)
    }

    @Test("Test Falling Strength Reduces Twenty To Thirty-Three Percent")
    func testFallingStrengthReduces() {
        let result = VolumeRecommendation.recommend(inputs(trend: -1))
        #expect(result.action == .reduce)
        // 12 × 0.67 = 8.04 → 8; 12 × 0.8 = 9.6 → 10.
        #expect(result.suggestedSets == 8...10)
    }

    /// Effort rising at the same load is fatigue even while the lifts still climb.
    @Test("Test Rising RPE At The Same Load Reduces")
    func testRisingRPEReduces() {
        #expect(VolumeRecommendation.recommend(inputs(trend: 2, rpeDrift: 1)).action == .reduce)
        #expect(VolumeRecommendation.recommend(inputs(trend: 2, rpeDrift: 0.5)).action == .keep)
    }

    @Test("Test Missed Planned Sets Come First")
    func testMissedPlannedSetsComeFirst() {
        let result = VolumeRecommendation.recommend(inputs(trend: -3, adherence: 0.7))
        #expect(result.action == .beConsistent)
        #expect(VolumeRecommendation.recommend(inputs(trend: 0, adherence: 0.8)).action == .add)
    }

    @Test("Test The Flat Band Edges", arguments: [
        (0.5, VolumeRecommendation.Action.add), (-0.5, .add), (0.51, .keep), (-0.51, .reduce)
    ])
    func testTheFlatBandEdges(trend: Double, expected: VolumeRecommendation.Action) {
        #expect(VolumeRecommendation.recommend(inputs(trend: trend)).action == expected)
    }

    @Test("Test Too Little History Asks For More")
    func testTooLittleHistory() {
        #expect(VolumeRecommendation.recommend(inputs(weeks: [0, 0, 0, 6])).action == .needsMoreData)
        #expect(VolumeRecommendation.recommend(inputs(trend: nil)).action == .needsMoreData)
        #expect(VolumeRecommendation.recommend(inputs(weeks: [])).suggestedSets == nil)
    }

    /// Fewer than four trained weeks: the baseline starts from the productive band.
    @Test("Test A New User Starts From The Productive Band")
    func testANewUserStartsFromTheProductiveBand() {
        let result = VolumeRecommendation.recommend(inputs(weeks: [0, 0, 3, 3], trend: 2))
        #expect(result.action == .keep)
        #expect(result.suggestedSets == 10...10)
    }

    @Test("Test A Reduction Never Goes Under The Floor")
    func testAReductionNeverGoesUnderTheFloor() {
        let young = VolumeRecommendation.recommend(inputs(weeks: [5, 5, 5, 5], trend: -2))
        #expect(young.suggestedSets?.lowerBound == 4)
        let older = VolumeRecommendation.recommend(inputs(weeks: [5, 5, 5, 5], trend: -2, age: 65))
        #expect(older.suggestedSets == 6...6)
    }

    @Test("Test Over Twenty Sets Is Flagged As High")
    func testOverTwentyIsHigh() {
        #expect(VolumeRecommendation.recommend(inputs(weeks: [22, 24, 22, 24])).isHighVolume)
        #expect(!VolumeRecommendation.recommend(inputs()).isHighVolume)
    }

    @Test("Test The Baseline Is The Median Week")
    func testTheBaselineIsTheMedian() {
        #expect(VolumeRecommendation.median([4, 20, 10, 12]) == 11)
        #expect(VolumeRecommendation.median([3, 1, 2]) == 2)
        #expect(VolumeRecommendation.median([]) == nil)
    }

    // MARK: - Trend and drift

    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func day(_ offset: Int) -> Date { day0.addingTimeInterval(Double(offset) * 86_400) }

    @Test("Test The Trend Is Percent Of The Mean Per Week")
    func testTheTrendIsPercentPerWeek() throws {
        // +1 kg a week around a 100 kg mean is +1% a week.
        let points = [(date: day(0), value: 99.0), (date: day(7), value: 100.0), (date: day(14), value: 101.0)]
        let trend = try #require(VolumeRecommendation.trendPercentPerWeek(points))
        #expect(abs(trend - 1) < 1e-9)
    }

    @Test("Test A Trend Needs Three Sessions Over A Week")
    func testATrendNeedsEnoughPoints() {
        #expect(VolumeRecommendation.trendPercentPerWeek([(date: day(0), value: 100), (date: day(7), value: 101)]) == nil)
        #expect(VolumeRecommendation.trendPercentPerWeek([(date: day(0), value: 100), (date: day(2), value: 101), (date: day(4), value: 102)]) == nil)
    }

    @Test("Test RPE Drift Compares The Same Load")
    func testRPEDriftComparesTheSameLoad() {
        let midpoint = day(14)
        let sets = [
            VolumeRecommendation.EffortSample(date: day(1), weightKg: 100, rpe: 7),
            VolumeRecommendation.EffortSample(date: day(3), weightKg: 100, rpe: 7),
            VolumeRecommendation.EffortSample(date: day(20), weightKg: 100, rpe: 8.5),
            // A heavier load only after the midpoint has nothing to compare with.
            VolumeRecommendation.EffortSample(date: day(21), weightKg: 110, rpe: 9.5)
        ]
        #expect(VolumeRecommendation.rpeDrift(sets, midpoint: midpoint) == 1.5)
        #expect(VolumeRecommendation.rpeDrift(Array(sets.prefix(2)), midpoint: midpoint) == nil)
    }

    // MARK: - From sessions

    @Test("Test Inputs Read Adherence From Planned Sets On Exercises That Train The Muscle")
    func testInputsReadAdherence() {
        let calendar = Calendar.current
        let end = day(27)
        let bench = AnalyticsExerciseFixture.exercise(id: "bench", muscles: [.chest: .primary])
        let fly = AnalyticsExerciseFixture.exercise(id: "fly", muscles: [.chest: .secondary])
        func session(_ id: String, offset: Int, templateId: String, done: Int, planned: Int) -> WorkoutSessionModel {
            let date = day(offset)
            let sets = (0..<planned).map { index in
                WorkoutSetModel(
                    id: "\(id)-\(index)", authorId: "author-1", index: index, reps: 8, weightKg: 100,
                    isWarmup: false, completedAt: index < done ? date : nil, dateCreated: date
                )
            }
            return WorkoutSessionModel(
                id: id, authorId: "author-1", name: "Push", dateCreated: date, endedAt: date,
                exercises: [WorkoutExerciseModel(
                    id: "we-\(id)", authorId: "author-1", templateId: templateId, name: "x", trackingMode: .weightReps, index: 1,
                    sets: sets, setTargets: (1...planned).map { SetTarget(setNumber: $0) }
                )]
            )
        }
        let result = VolumeRecommendation.inputs(
            muscle: .chest,
            sessions: [
                session("a", offset: 10, templateId: "bench", done: 3, planned: 4),
                session("b", offset: 20, templateId: "bench", done: 4, planned: 4),
                // Only exercises that train the muscle directly count towards adherence.
                session("c", offset: 21, templateId: "fly", done: 0, planned: 4)
            ],
            templates: ["bench": bench, "fly": fly],
            age: nil,
            calendar: calendar,
            endDate: end
        )
        #expect(result.adherence == 7.0 / 8.0)
        #expect(result.weeklySets.count == VolumeRecommendation.windowWeeks)
    }
}
