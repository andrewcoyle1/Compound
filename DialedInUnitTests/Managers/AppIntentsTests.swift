//
//  AppIntentsTests.swift
//  DialedInUnitTests
//

import Foundation
import Testing
@testable import DialedIn

@MainActor
struct AppIntentsTests {

    // MARK: - Start workout

    @Test func startWorkoutStartsTheTemplateAndRequestsTheTracker() async throws {
        let template = Self.template(name: "Push Day")
        let stub = StubAppIntentsInteractor(user: Self.user(), templates: [template])

        let sentence = try await stub.startWorkoutFromIntent(templateId: template.id)

        #expect(sentence == "Starting Push Day.")
        #expect(stub.startedTemplateIds == [template.id])
        #expect(stub.startedProgramIds == [nil])
        #expect(stub.trackerOpenCount == 1)
    }

    @Test func startWorkoutPassesTheProgrammeForAProgrammeDay() async throws {
        let template = Self.template(name: "Legs")
        let program = Self.program([template])
        let stub = StubAppIntentsInteractor(user: Self.user(), program: program)

        _ = try await stub.startWorkoutFromIntent(templateId: template.id)

        #expect(stub.startedProgramIds == [program.id])
    }

    @Test func startWorkoutKeepsAnActiveSession() async throws {
        let template = Self.template(name: "Push Day")
        let stub = StubAppIntentsInteractor(user: Self.user(), templates: [template])
        stub.activeSession = WorkoutSessionModel(authorId: "me", name: "Pull Day", dateCreated: .now, exercises: [])

        let sentence = try await stub.startWorkoutFromIntent(templateId: template.id)

        #expect(sentence == "You already have Pull Day in progress, so I've opened that instead.")
        #expect(stub.startedTemplateIds.isEmpty)
        #expect(stub.trackerOpenCount == 1)
    }

    @Test func startWorkoutThrowsForAnUnknownTemplate() async {
        let stub = StubAppIntentsInteractor(user: Self.user())
        await #expect(throws: AppIntentsError.workoutNotFound) {
            try await stub.startWorkoutFromIntent(templateId: "missing")
        }
    }

    @Test func startWorkoutThrowsWhenSignedOut() async {
        let stub = StubAppIntentsInteractor(user: nil)
        await #expect(throws: AppIntentsError.notSignedIn) {
            try await stub.startWorkoutFromIntent(templateId: "any")
        }
    }

    // MARK: - Log weight

    @Test func logWeightInKilogramsSavesEntryAndProfile() async throws {
        let stub = StubAppIntentsInteractor(user: Self.user())

        let sentence = try await stub.logWeightFromIntent(value: 80.5, unit: .kilograms)

        #expect(sentence == "Logged 80.5 kg.")
        #expect(stub.savedMeasurements.map { $0.weightKg } == [80.5])
        #expect(stub.updatedWeights.map { $0.kilograms } == [80.5])
        #expect(stub.updatedWeights.map { $0.unit } == [.kilograms])
    }

    @Test func logWeightWithoutAUnitUsesThePreference() async throws {
        let stub = StubAppIntentsInteractor(user: Self.user(unit: .pounds))

        let sentence = try await stub.logWeightFromIntent(value: 176, unit: nil)

        #expect(sentence == "Logged 176.0 lb.")
        let kilograms = try #require(stub.savedMeasurements.first?.weightKg)
        #expect(abs(kilograms - UnitConversion.lbsToKg(176)) < 0.001)
    }

    @Test func logWeightRejectsImplausibleValues() async {
        let stub = StubAppIntentsInteractor(user: Self.user())
        await #expect(throws: AppIntentsError.weightOutOfRange) {
            try await stub.logWeightFromIntent(value: 5, unit: .kilograms)
        }
        #expect(stub.savedMeasurements.isEmpty)
    }

    // MARK: - Workouts this week

    @Test func workoutsThisWeekCountsFinishedSessions() throws {
        let now = Date()
        let finished = { WorkoutSessionModel(authorId: "me", name: "W", dateCreated: now, endedAt: now, exercises: []) }
        let unfinished = WorkoutSessionModel(authorId: "me", name: "W", dateCreated: now, exercises: [])
        let stub = StubAppIntentsInteractor(user: Self.user(goal: 3), sessions: [finished(), finished(), unfinished])

        let answer = try stub.workoutsThisWeek(now: now)

        #expect(answer.count == 2)
        #expect(answer.sentence == "You've done 2 workouts this week, 1 to go to hit your goal of 3.")
    }

    @Test func workoutsThisWeekPhrasing() {
        #expect(AppIntentsPhrasing.workoutsThisWeek(count: 0, goal: 3) == "You haven't trained yet this week. Your goal is 3.")
        #expect(AppIntentsPhrasing.workoutsThisWeek(count: 1, goal: 3) == "You've done 1 workout this week, 2 to go to hit your goal of 3.")
        #expect(AppIntentsPhrasing.workoutsThisWeek(count: 4, goal: 3) == "You've done 4 workouts this week, so you've hit your goal of 3.")
    }

    // MARK: - Next workout

    @Test func nextWorkoutWithoutAProgramme() throws {
        let answer = try StubAppIntentsInteractor(user: Self.user()).nextWorkout()
        #expect(answer.template == nil)
        #expect(answer.sentence == AppIntentsPhrasing.noProgram)
    }

    @Test func nextWorkoutNamesTodaysPlan() throws {
        let template = Self.template(name: "Upper", exerciseCount: 2)
        let stub = StubAppIntentsInteractor(user: Self.user(), program: Self.program([template]))

        let answer = try stub.nextWorkout()

        #expect(answer.template?.id == template.id)
        #expect(answer.sentence == "Today's workout is Upper, 2 exercises.")
    }

    @Test func nextWorkoutOnARestDay() throws {
        let rest = Self.template(name: "Rest", exerciseCount: 0)
        let stub = StubAppIntentsInteractor(user: Self.user(), program: Self.program([rest], name: "Block 1"))

        let answer = try stub.nextWorkout()

        #expect(answer.template == nil)
        #expect(answer.sentence == "Today is a rest day in Block 1.")
    }

    @Test func nextWorkoutAlreadyDoneToday() throws {
        let template = Self.template(name: "Upper")
        let program = Self.program([template])
        let now = Date()
        let done = WorkoutSessionModel(
            authorId: "me", name: "Upper", workoutTemplateId: template.id, trainingProgramId: program.id,
            dateCreated: now, endedAt: now, exercises: []
        )
        let stub = StubAppIntentsInteractor(user: Self.user(), program: program, sessions: [done])

        let answer = try stub.nextWorkout(now: now)

        #expect(answer.sentence == "You've already done today's workout, Upper.")
    }

    // MARK: - Fixtures

    private static func user(unit: WeightUnitPreference? = nil, goal: Int? = nil) -> UserModel {
        UserModel(userId: "me", submittedWeightUnitPreference: unit, weeklySessionGoal: goal)
    }

    private static func template(name: String, exerciseCount: Int = 1) -> WorkoutTemplateModel {
        let exercises = Array((WorkoutTemplateModel.mocks.first { $0.exercises.count >= 2 }?.exercises ?? []).prefix(exerciseCount))
        return WorkoutTemplateModel(id: "template-\(name)", authorId: "me", name: name, exercises: exercises)
    }

    private static func program(_ templates: [WorkoutTemplateModel], name: String = "Block") -> TrainingProgram {
        TrainingProgram(id: "program-1", authorId: "me", name: name, icon: "dumbbell", colour: "#FF0000", workoutTemplates: templates)
    }
}

@MainActor
private final class StubAppIntentsInteractor: AppIntentsInteractor {
    var currentUser: UserModel?
    var activeSession: WorkoutSessionModel?
    var workoutSessions: [WorkoutSessionModel]
    var activeTrainingProgram: TrainingProgram?
    var allWorkoutTemplates: [WorkoutTemplateModel]

    private(set) var trackerOpenCount = 0
    private(set) var startedTemplateIds: [String] = []
    private(set) var startedProgramIds: [String?] = []
    private(set) var savedMeasurements: [BodyMeasurementEntry] = []
    private(set) var updatedWeights: [(kilograms: Double, unit: WeightUnitPreference)] = []

    init(
        user: UserModel?,
        templates: [WorkoutTemplateModel] = [],
        program: TrainingProgram? = nil,
        sessions: [WorkoutSessionModel] = []
    ) {
        currentUser = user
        allWorkoutTemplates = templates
        activeTrainingProgram = program
        workoutSessions = sessions
    }

    func startWorkout(for template: WorkoutTemplateModel, in trainingProgramId: String?) async throws {
        startedTemplateIds.append(template.id)
        startedProgramIds.append(trainingProgramId)
    }

    func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws {
        savedMeasurements.append(bodyMeasurement)
    }

    func updateWeight(userId: String, weight: Double, weightUnitPreference: WeightUnitPreference) async throws {
        updatedWeights.append((weight, weightUnitPreference))
    }

    func openWorkoutTracker() {
        trackerOpenCount += 1
    }
}
