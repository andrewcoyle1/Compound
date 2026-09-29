//
//  DialedInAppIntents.swift
//  DialedIn
//
//  Siri and Shortcuts. Each intent runs in the app process and hands straight to
//  `AppIntentsInteractor`, where the behaviour and the wording live.
//

import AppIntents

// MARK: - Entities

struct WorkoutTemplateEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Workout"
    static let defaultQuery = WorkoutTemplateQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(_ template: WorkoutTemplateModel) {
        self.init(id: template.id, name: template.name)
    }
}

struct WorkoutTemplateQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [WorkoutTemplateEntity] {
        templates.filter { identifiers.contains($0.id) }.map(WorkoutTemplateEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [WorkoutTemplateEntity] {
        templates.filter { $0.name.localizedCaseInsensitiveContains(string) }.map(WorkoutTemplateEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [WorkoutTemplateEntity] {
        templates.map(WorkoutTemplateEntity.init)
    }

    @MainActor
    private var templates: [WorkoutTemplateModel] {
        AppIntentsBridge.interactor?.startableWorkoutTemplates ?? []
    }
}

enum WeightUnitAppEnum: String, AppEnum {
    case kilograms
    case pounds

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Unit"
    static let caseDisplayRepresentations: [WeightUnitAppEnum: DisplayRepresentation] = [
        .kilograms: "kg",
        .pounds: "lb"
    ]

    var preference: WeightUnitPreference { self == .kilograms ? .kilograms : .pounds }
}

// MARK: - Ready interactor

@MainActor
private extension AppIntent {
    /// The shared interactor once someone is signed in. A background launch has no scene, so
    /// nothing has signed in yet: bring the app forward, which runs the normal sign-in, and give
    /// its listeners a moment to deliver the profile.
    func readyInteractor() async throws -> any AppIntentsInteractor {
        if let interactor = AppIntentsBridge.interactor, interactor.currentUser != nil { return interactor }
        try await continueInForeground(alwaysConfirm: false)
        for _ in 0..<50 {
            if let interactor = AppIntentsBridge.interactor, interactor.currentUser != nil { return interactor }
            try await Task.sleep(for: .milliseconds(200))
        }
        throw AppIntentsError.notSignedIn
    }
}

// MARK: - Intents

struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Workout"
    static let description: IntentDescription = "Start one of your workouts and open the tracker."
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Workout")
    var workout: WorkoutTemplateEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$workout)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let sentence = try await readyInteractor().startWorkoutFromIntent(templateId: workout.id)
        return .result(dialog: IntentDialog(stringLiteral: sentence))
    }
}

struct LogWeightIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Weight"
    static let description: IntentDescription = "Record today's body weight."
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Parameter(title: "Weight")
    var value: Double

    /// Left empty, the unit is the one set in the app.
    @Parameter(title: "Unit")
    var unit: WeightUnitAppEnum?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$value) \(\.$unit)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let sentence = try await readyInteractor().logWeightFromIntent(value: value, unit: unit?.preference)
        return .result(dialog: IntentDialog(stringLiteral: sentence))
    }
}

struct WorkoutsThisWeekIntent: AppIntent {
    static let title: LocalizedStringResource = "Workouts This Week"
    static let description: IntentDescription = "How many workouts you've finished this week."
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let answer = try await readyInteractor().workoutsThisWeek()
        return .result(value: answer.count, dialog: IntentDialog(stringLiteral: answer.sentence))
    }
}

struct NextWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's Workout"
    static let description: IntentDescription = "The workout your active programme has for today."
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<WorkoutTemplateEntity?> & ProvidesDialog {
        let answer = try await readyInteractor().nextWorkout()
        return .result(value: answer.template.map(WorkoutTemplateEntity.init), dialog: IntentDialog(stringLiteral: answer.sentence))
    }
}

// MARK: - App Shortcuts

struct DialedInAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start \(\.$workout) in \(.applicationName)",
                "Start a workout in \(.applicationName)",
                "Start my \(.applicationName) workout"
            ],
            shortTitle: "Start Workout",
            systemImageName: "play.circle.fill"
        )
        AppShortcut(
            intent: LogWeightIntent(),
            phrases: [
                "Log my weight in \(.applicationName)",
                "Log weight in \(.applicationName)"
            ],
            shortTitle: "Log Weight",
            systemImageName: "scalemass"
        )
        AppShortcut(
            intent: WorkoutsThisWeekIntent(),
            phrases: [
                "How many workouts this week in \(.applicationName)",
                "How many times have I trained this week in \(.applicationName)"
            ],
            shortTitle: "Workouts This Week",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: NextWorkoutIntent(),
            phrases: [
                "What's my workout today in \(.applicationName)",
                "What's my next \(.applicationName) workout"
            ],
            shortTitle: "Today's Workout",
            systemImageName: "figure.strengthtraining.traditional"
        )
    }
}
