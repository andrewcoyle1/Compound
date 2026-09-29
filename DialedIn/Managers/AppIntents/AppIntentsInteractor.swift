//
//  AppIntentsInteractor.swift
//  DialedIn
//
//  What the Siri / Shortcuts intents need from the app, and the sentences they answer with. The
//  intents themselves (`DialedInAppIntents.swift`) only fetch `AppIntentsBridge.interactor` and
//  hand over, so everything here is testable with a stub instead of a running app.
//

import Foundation

@MainActor
protocol AppIntentsInteractor {
    var currentUser: UserModel? { get }
    var activeSession: WorkoutSessionModel? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    var activeTrainingProgram: TrainingProgram? { get }
    var allWorkoutTemplates: [WorkoutTemplateModel] { get }
    func startWorkout(for template: WorkoutTemplateModel, in trainingProgramId: String?) async throws
    func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws
    func updateWeight(userId: String, weight: Double, weightUnitPreference: WeightUnitPreference) async throws
    func openWorkoutTracker()
}

extension CoreInteractor: AppIntentsInteractor {
    /// The widget's `compound://workout`, queued like a tapped push: on a cold launch the intent
    /// finishes before the tab bar exists, and the tab bar takes the link once it is signed in.
    func openWorkoutTracker() {
        pushManager.storePendingDeepLink(.workout)
        NotificationCenter.default.post(name: .pushNotification, object: nil)
    }
}

/// The one route from an intent into the running app. Set by `AppDelegate`, which runs before
/// any `perform()`, even on a launch made for an intent.
@MainActor
enum AppIntentsBridge {
    static var interactor: (any AppIntentsInteractor)?
}

enum AppIntentsError: LocalizedError, Equatable {
    case notSignedIn
    case workoutNotFound
    case weightOutOfRange

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return String(localized: "Open DialedIn and sign in first.")
        case .workoutNotFound: return String(localized: "That workout isn't in your library any more.")
        case .weightOutOfRange: return String(localized: "That doesn't look like a body weight. Try again with a number between 20 and 400 kg.")
        }
    }
}

// MARK: - Actions

extension AppIntentsInteractor {

    /// The library plus the active programme's day plans, which are not always saved as templates.
    /// First id wins, so a library template is preferred over its programme copy.
    var startableWorkoutTemplates: [WorkoutTemplateModel] {
        var seen = Set<String>()
        let program = activeTrainingProgram?.workoutTemplates.filter { !$0.exercises.isEmpty } ?? []
        return (allWorkoutTemplates + program).filter { seen.insert($0.id).inserted }
    }

    /// Starts `templateId` and asks for the tracker. An active session is kept, not replaced:
    /// a voice command should never throw away a half-logged workout.
    func startWorkoutFromIntent(templateId: String) async throws -> String {
        guard currentUser != nil else { throw AppIntentsError.notSignedIn }
        if let active = activeSession {
            openWorkoutTracker()
            return AppIntentsPhrasing.alreadyInProgress(name: active.name)
        }
        guard let template = startableWorkoutTemplates.first(where: { $0.id == templateId }) else {
            throw AppIntentsError.workoutNotFound
        }
        let program = activeTrainingProgram
        let programId = program?.workoutTemplates.contains { $0.id == template.id } == true ? program?.id : nil
        try await startWorkout(for: template, in: programId)
        openWorkoutTracker()
        return AppIntentsPhrasing.started(name: template.name)
    }

    /// Writes the entry and the profile's current weight, as the Log Weight screen does.
    /// `unit` nil means the user's own preference.
    func logWeightFromIntent(value: Double, unit: WeightUnitPreference?, date: Date = Date()) async throws -> String {
        guard let user = currentUser else { throw AppIntentsError.notSignedIn }
        let unit = unit ?? user.submittedWeightUnitPreference ?? .kilograms
        let weightKg = UnitConversion.convertWeightToKg(value, from: unit)
        guard (20...400).contains(weightKg) else { throw AppIntentsError.weightOutOfRange }
        try await saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry(authorId: user.userId, weightKg: weightKg, date: date))
        try await updateWeight(userId: user.userId, weight: weightKg, weightUnitPreference: unit)
        return AppIntentsPhrasing.loggedWeight(value, unit: unit)
    }

    func workoutsThisWeek(now: Date = Date(), calendar: Calendar = .current) throws -> (count: Int, sentence: String) {
        guard let user = currentUser else { throw AppIntentsError.notSignedIn }
        let count = CircleWeek.sessionCount(of: user.userId, inWeekOf: now, sessions: workoutSessions, calendar: calendar)
        return (count, AppIntentsPhrasing.workoutsThisWeek(count: count, goal: CircleWeek.goal(for: user)))
    }

    func nextWorkout(now: Date = Date(), calendar: Calendar = .current) throws -> (template: WorkoutTemplateModel?, sentence: String) {
        guard currentUser != nil else { throw AppIntentsError.notSignedIn }
        guard let program = activeTrainingProgram else { return (nil, AppIntentsPhrasing.noProgram) }
        guard let item = TodaysWorkoutSchedule.item(program: program, sessions: workoutSessions, now: now, calendar: calendar) else {
            return (nil, AppIntentsPhrasing.noProgram)
        }
        if item.dayPlan.exercises.isEmpty {
            return (nil, AppIntentsPhrasing.restDay(program: program.name))
        }
        if item.isCompleted {
            return (item.dayPlan, AppIntentsPhrasing.alreadyDone(name: item.dayPlan.name))
        }
        return (item.dayPlan, AppIntentsPhrasing.today(name: item.dayPlan.name, exercises: item.dayPlan.exercises.count))
    }
}

// MARK: - Phrasing

enum AppIntentsPhrasing {
    static let noProgram = "You don't have an active programme. Pick one in the Training tab."

    static func started(name: String) -> String { "Starting \(name)." }

    static func alreadyInProgress(name: String) -> String {
        "You already have \(name) in progress, so I've opened that instead."
    }

    static func loggedWeight(_ value: Double, unit: WeightUnitPreference) -> String {
        "Logged \(String(format: "%.1f", value)) \(unit == .kilograms ? "kg" : "lb")."
    }

    static func workoutsThisWeek(count: Int, goal: Int) -> String {
        let done = "\(count) \(count == 1 ? "workout" : "workouts")"
        if count == 0 { return "You haven't trained yet this week. Your goal is \(goal)." }
        let remaining = CircleWeek.remaining(sessions: count, goal: goal)
        if remaining == 0 { return "You've done \(done) this week, so you've hit your goal of \(goal)." }
        return "You've done \(done) this week, \(remaining) to go to hit your goal of \(goal)."
    }

    static func restDay(program: String) -> String { "Today is a rest day in \(program)." }

    static func alreadyDone(name: String) -> String { "You've already done today's workout, \(name)." }

    static func today(name: String, exercises: Int) -> String {
        "Today's workout is \(name), \(exercises) \(exercises == 1 ? "exercise" : "exercises")."
    }
}
