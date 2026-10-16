//
//  AppIntents.swift
//  Runner
//
//  Siri and Shortcuts, from the Swift app's `Managers/AppIntents/DialedInAppIntents.swift`. Each
//  intent runs in the app process and hands straight to Dart (`AppIntentHandler` in
//  notifications_repository), where the behaviour and the wording live, over
//  `com.andrewcoyle.compound/app_intents`. Browse Recipes is the Swift app's `browse_recipes`
//  quick action.
//

import AppIntents
import Flutter
import Foundation

// MARK: - The channel

/// The one route from an intent into Dart (Swift `AppIntentsBridge`). Set up with the engine, which
/// a launch made for an intent starts before any `perform()` runs.
@MainActor
final class AppIntentsChannel {
  static var shared: AppIntentsChannel?

  private let channel: FlutterMethodChannel
  private var dartReady = false
  private var readyWaiters: [CheckedContinuation<Void, Never>] = []

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.andrewcoyle.compound/app_intents", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self, call.method == "ready" else { return result(FlutterMethodNotImplemented) }
      self.dartReady = true
      self.readyWaiters.forEach { $0.resume() }
      self.readyWaiters.removeAll()
      result(nil)
    }
  }

  /// Calls Dart once it is listening, and answers what it answers. Its refusals (signed out, a
  /// workout gone, a weight out of range) come back as their sentence.
  func call(_ method: String, _ arguments: [String: Any] = [:]) async throws -> Any? {
    if !dartReady {
      await withCheckedContinuation { (waiter: CheckedContinuation<Void, Never>) in
        readyWaiters.append(waiter)
        Task {
          try? await Task.sleep(nanoseconds: 10_000_000_000)
          self.readyWaiters.forEach { $0.resume() }
          self.readyWaiters.removeAll()
        }
      }
    }
    return try await withCheckedThrowingContinuation { continuation in
      channel.invokeMethod(method, arguments: arguments) { answer in
        if let error = answer as? FlutterError {
          continuation.resume(throwing: AppIntentsError.refused(error.message ?? ""))
        } else if (answer as? NSObject) === FlutterMethodNotImplemented {
          continuation.resume(throwing: AppIntentsError.notReady)
        } else {
          continuation.resume(returning: answer)
        }
      }
    }
  }
}

enum AppIntentsError: LocalizedError {
  case refused(String)
  case notReady

  var errorDescription: String? {
    switch self {
    case let .refused(sentence): return sentence
    case .notReady: return String(localized: "Open Compound and sign in first.")
    }
  }
}

@available(iOS 16.0, *)
private func askDart(_ method: String, _ arguments: [String: Any] = [:]) async throws -> [String: Any] {
  guard let channel = await AppIntentsChannel.shared else { throw AppIntentsError.notReady }
  return try await channel.call(method, arguments) as? [String: Any] ?? [:]
}

// MARK: - Entities

@available(iOS 16.0, *)
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

  init?(_ json: Any?) {
    guard let json = json as? [String: Any], let id = json["id"] as? String, let name = json["name"] as? String
    else { return nil }
    self.init(id: id, name: name)
  }
}

@available(iOS 16.0, *)
struct WorkoutTemplateQuery: EntityStringQuery {
  func entities(for identifiers: [String]) async throws -> [WorkoutTemplateEntity] {
    try await templates().filter { identifiers.contains($0.id) }
  }

  func entities(matching string: String) async throws -> [WorkoutTemplateEntity] {
    try await templates().filter { $0.name.localizedCaseInsensitiveContains(string) }
  }

  func suggestedEntities() async throws -> [WorkoutTemplateEntity] {
    try await templates()
  }

  /// The library plus the active programme's day plans (`startableWorkoutTemplates`).
  private func templates() async throws -> [WorkoutTemplateEntity] {
    let answer = try await askDart("workouts")
    return (answer["workouts"] as? [Any] ?? []).compactMap(WorkoutTemplateEntity.init)
  }
}

@available(iOS 16.0, *)
enum WeightUnitAppEnum: String, AppEnum {
  case kilograms
  case pounds

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Unit"
  static let caseDisplayRepresentations: [WeightUnitAppEnum: DisplayRepresentation] = [
    .kilograms: "kg",
    .pounds: "lb",
  ]
}

// MARK: - Intents

@available(iOS 16.0, *)
struct StartWorkoutIntent: AppIntent {
  static let title: LocalizedStringResource = "Start Workout"
  static let description = IntentDescription("Start one of your workouts and open the tracker.")
  static let openAppWhenRun = true

  @Parameter(title: "Workout")
  var workout: WorkoutTemplateEntity

  static var parameterSummary: some ParameterSummary {
    Summary("Start \(\.$workout)")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let answer = try await askDart("startWorkout", ["id": workout.id])
    return .result(dialog: IntentDialog(stringLiteral: answer["sentence"] as? String ?? ""))
  }
}

@available(iOS 16.0, *)
struct LogWeightIntent: AppIntent {
  static let title: LocalizedStringResource = "Log Weight"
  static let description = IntentDescription("Record today's body weight.")

  @Parameter(title: "Weight")
  var value: Double

  /// Left empty, the unit is the one set in the app.
  @Parameter(title: "Unit")
  var unit: WeightUnitAppEnum?

  static var parameterSummary: some ParameterSummary {
    Summary("Log \(\.$value) \(\.$unit)")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    var arguments: [String: Any] = ["value": value]
    if let unit { arguments["unit"] = unit.rawValue }
    let answer = try await askDart("logWeight", arguments)
    return .result(dialog: IntentDialog(stringLiteral: answer["sentence"] as? String ?? ""))
  }
}

@available(iOS 16.0, *)
struct WorkoutsThisWeekIntent: AppIntent {
  static let title: LocalizedStringResource = "Workouts This Week"
  static let description = IntentDescription("How many workouts you've finished this week.")

  func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
    let answer = try await askDart("workoutsThisWeek")
    return .result(
      value: answer["count"] as? Int ?? 0,
      dialog: IntentDialog(stringLiteral: answer["sentence"] as? String ?? "")
    )
  }
}

@available(iOS 16.0, *)
struct NextWorkoutIntent: AppIntent {
  static let title: LocalizedStringResource = "Today's Workout"
  static let description = IntentDescription("The workout your active mesocycle has for today.")

  func perform() async throws -> some IntentResult & ReturnsValue<WorkoutTemplateEntity?> & ProvidesDialog {
    let answer = try await askDart("todaysWorkout")
    return .result(
      value: WorkoutTemplateEntity(answer["workout"]),
      dialog: IntentDialog(stringLiteral: answer["sentence"] as? String ?? "")
    )
  }
}

@available(iOS 16.0, *)
struct BrowseRecipesIntent: AppIntent {
  static let title: LocalizedStringResource = "Recipes"
  static let description = IntentDescription("Open your recipes.")
  static let openAppWhenRun = true

  func perform() async throws -> some IntentResult {
    _ = try await askDart("browseRecipes")
    return .result()
  }
}

// MARK: - App Shortcuts

@available(iOS 16.0, *)
struct CompoundAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: StartWorkoutIntent(),
      phrases: [
        "Start \(\.$workout) in \(.applicationName)",
        "Start a workout in \(.applicationName)",
        "Start my \(.applicationName) workout",
      ],
      shortTitle: "Start Workout",
      systemImageName: "play.circle.fill"
    )
    AppShortcut(
      intent: LogWeightIntent(),
      phrases: [
        "Log my weight in \(.applicationName)",
        "Log weight in \(.applicationName)",
      ],
      shortTitle: "Log Weight",
      systemImageName: "scalemass"
    )
    AppShortcut(
      intent: WorkoutsThisWeekIntent(),
      phrases: [
        "How many workouts this week in \(.applicationName)",
        "How many times have I trained this week in \(.applicationName)",
      ],
      shortTitle: "Workouts This Week",
      systemImageName: "calendar"
    )
    AppShortcut(
      intent: NextWorkoutIntent(),
      phrases: [
        "What's my workout today in \(.applicationName)",
        "What's my next \(.applicationName) workout",
      ],
      shortTitle: "Today's Workout",
      systemImageName: "figure.strengthtraining.traditional"
    )
    AppShortcut(
      intent: BrowseRecipesIntent(),
      phrases: [
        "Show my recipes in \(.applicationName)",
        "Open recipes in \(.applicationName)",
      ],
      shortTitle: "Recipes",
      systemImageName: "books.vertical"
    )
  }
}
