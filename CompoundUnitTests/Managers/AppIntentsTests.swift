//
//  AppIntentsTests.swift
//  CompoundUnitTests
//

import Foundation
import Testing
@testable import Compound

@MainActor
struct AppIntentsTests {

    // MARK: - Start workout

    @Test func startWorkoutStartsTheTemplateAndRequestsTheTracker() async throws {
        let template = Self.template(name: "Push Day")
        let stub = StubAppIntentsInteractor(user: Self.user(), templates: [template])

        let sentence = try await stub.startWorkoutFromIntent(templateId: template.id)

        #expect(sentence == "Starting Push Day.")
        #expect(stub.startedTemplateIds == [template.id])
        #expect(stub.startedMesocycleIds == [nil])
        #expect(stub.trackerOpenCount == 1)
    }

    @Test func startWorkoutPassesTheProgrammeForAProgrammeDay() async throws {
        let template = Self.template(name: "Legs")
        let mesocycle = Self.mesocycle([template])
        let stub = StubAppIntentsInteractor(user: Self.user(), mesocycle: mesocycle)

        _ = try await stub.startWorkoutFromIntent(templateId: template.id)

        #expect(stub.startedMesocycleIds == [mesocycle.id])
        #expect(stub.startedMicrocycles == [1])
    }

    /// Legs done twice already: the next Legs is in the third microcycle, and starts on its targets.
    @Test func startWorkoutPassesTheMicrocycleTheDayIsOpenIn() async throws {
        let template = Self.template(name: "Legs")
        let mesocycle = Mesocycle(id: "program-1", authorId: "me", name: "Block", icon: "dumbbell", colour: "#FF0000",
                                  numMicrocycles: 4, workoutTemplates: [template])
        let done = (1...2).map { day in
            let date = Date().addingTimeInterval(Double(day - 3) * 86_400)
            return WorkoutSessionModel(authorId: "me", name: "Legs", workoutTemplateId: template.id, mesocycleId: mesocycle.id,
                                       dateCreated: date, endedAt: date, exercises: [])
        }
        let stub = StubAppIntentsInteractor(user: Self.user(), mesocycle: mesocycle, sessions: done)

        _ = try await stub.startWorkoutFromIntent(templateId: template.id)

        #expect(stub.startedMicrocycles == [3])
    }

    @Test func startWorkoutPassesNoMicrocycleForALibraryTemplate() async throws {
        let template = Self.template(name: "Push Day")
        let stub = StubAppIntentsInteractor(user: Self.user(), templates: [template])

        _ = try await stub.startWorkoutFromIntent(templateId: template.id)

        #expect(stub.startedMicrocycles == [nil])
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
        #expect(answer.sentence == AppIntentsPhrasing.noMesocycle)
    }

    @Test func nextWorkoutNamesTodaysPlan() throws {
        let template = Self.template(name: "Upper", exerciseCount: 2)
        let stub = StubAppIntentsInteractor(user: Self.user(), mesocycle: Self.mesocycle([template]))

        let answer = try stub.nextWorkout()

        #expect(answer.template?.id == template.id)
        #expect(answer.sentence == "Today's workout is Upper, 2 exercises.")
    }

    /// A rest day is one the mesocycle pre-completed for today after the workout before it.
    @Test func nextWorkoutOnARestDay() throws {
        let upper = Self.template(name: "Upper")
        let rest = Self.template(name: "Rest", exerciseCount: 0)
        let mesocycle = Self.mesocycle([upper, rest], name: "Block 1")
        let now = Date()
        let restSession = WorkoutSessionModel(
            authorId: "me", name: "Rest", workoutTemplateId: rest.id, mesocycleId: mesocycle.id,
            dateCreated: now, endedAt: now, exercises: [], isRestDay: true
        )
        let stub = StubAppIntentsInteractor(user: Self.user(), mesocycle: mesocycle, sessions: [restSession])

        let answer = try stub.nextWorkout(now: now)

        #expect(answer.template == nil)
        #expect(answer.sentence == "Today is a rest day in Block 1.")
    }

    @Test func nextWorkoutAlreadyDoneToday() throws {
        let template = Self.template(name: "Upper")
        let mesocycle = Self.mesocycle([template])
        let now = Date()
        let done = WorkoutSessionModel(
            authorId: "me", name: "Upper", workoutTemplateId: template.id, mesocycleId: mesocycle.id,
            dateCreated: now, endedAt: now, exercises: []
        )
        let stub = StubAppIntentsInteractor(user: Self.user(), mesocycle: mesocycle, sessions: [done])

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

    private static func mesocycle(_ templates: [WorkoutTemplateModel], name: String = "Block") -> Mesocycle {
        Mesocycle(id: "program-1", authorId: "me", name: name, icon: "dumbbell", colour: "#FF0000", workoutTemplates: templates)
    }
}

@MainActor
private final class StubAppIntentsInteractor: AppIntentsInteractor {
    var currentUser: UserModel?
    var activeSession: WorkoutSessionModel?
    var workoutSessions: [WorkoutSessionModel]
    var activeMesocycle: Mesocycle?
    var allWorkoutTemplates: [WorkoutTemplateModel]

    /// The mesocycle followed from the start of time, so every fixture session counts.
    var activeMesocycleRun: MesocycleSchedule.Run? {
        activeMesocycle.map { MesocycleSchedule.Run(mesocycle: $0, startedAt: .distantPast) }
    }

    private(set) var trackerOpenCount = 0
    private(set) var startedTemplateIds: [String] = []
    private(set) var startedMesocycleIds: [String?] = []
    private(set) var startedMicrocycles: [Int?] = []
    private(set) var savedMeasurements: [BodyMeasurementEntry] = []
    private(set) var updatedWeights: [(kilograms: Double, unit: WeightUnitPreference)] = []

    init(
        user: UserModel?,
        templates: [WorkoutTemplateModel] = [],
        mesocycle: Mesocycle? = nil,
        sessions: [WorkoutSessionModel] = []
    ) {
        currentUser = user
        allWorkoutTemplates = templates
        activeMesocycle = mesocycle
        workoutSessions = sessions
    }

    func startWorkout(for template: WorkoutTemplateModel, in mesocycleId: String?, microcycleIndex: Int?) async throws {
        startedTemplateIds.append(template.id)
        startedMesocycleIds.append(mesocycleId)
        startedMicrocycles.append(microcycleIndex)
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
