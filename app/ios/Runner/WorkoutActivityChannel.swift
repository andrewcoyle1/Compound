import Flutter
import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif
import WidgetKit

/// The Live Activity, driven from Dart (`LiveActivityRepository` in notifications_repository). The
/// Swift app's `LiveActivityManager` works out what to show from its managers; here Dart works it
/// out and this only hands it to ActivityKit. The home-screen widgets' snapshot reaches the App
/// Group through the home_widget plugin (`PluginHomeWidgetRepository`).
///
/// The Live Activity's buttons (`WorkoutRestTimerIntents.swift`) run in this process and reach
/// Dart through this object as their `LiveActivityIntentHandling`.
@MainActor
final class WorkoutActivityChannel: NSObject {

  private let activity: FlutterMethodChannel

  /// The last content state Dart sent, so the activity can be ended with its summary and a tap
  /// that changed nothing can still take the loading state off.
  private var lastState: Data?

  /// Dart has registered its handler for the buttons. A tap that launched the app arrives before
  /// it has, and waits for it a little.
  private var dartReady = false
  private var readyWaiters: [CheckedContinuation<Void, Never>] = []

  /// How long a tap waits for Dart to be ready, then for its answer.
  private static let readyTimeout: UInt64 = 10_000_000_000

  init(messenger: FlutterBinaryMessenger) {
    activity = FlutterMethodChannel(name: "com.andrewcoyle.compound/live_activity", binaryMessenger: messenger)
    super.init()
    activity.setMethodCallHandler { [weak self] call, result in self?.handleActivity(call, result: result) }
    if #available(iOS 17.0, *) {
      LiveActivityIntentHandler.current = self
    }
  }

  // MARK: - Live Activity

  private func handleActivity(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "isAvailable":
      result(Self.isAvailable)
    case "ready":
      dartReady = true
      readyWaiters.forEach { $0.resume() }
      readyWaiters.removeAll()
      result(nil)
    case "show":
      guard #available(iOS 17.0, *), Self.isAvailable else { return result(false) }
      Task { result(await self.show(arguments)) }
    case "end":
      guard #available(iOS 17.0, *) else { return result(nil) }
      Task {
        await self.end(arguments)
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Live Activities are on for the app, on a system whose activity has its buttons.
  private static var isAvailable: Bool {
    guard #available(iOS 17.0, *) else { return false }
    return ActivityAuthorizationInfo().areActivitiesEnabled
  }

  /// Starts the session's activity, or updates it (`ensureLiveActivity`). Anything else still up
  /// belongs to an earlier workout. With `alert`, the update announces the end of a rest
  /// (`announceRestOver`). Answers whether an activity is showing.
  @available(iOS 17.0, *)
  private func show(_ arguments: [String: Any]) async -> Bool {
    guard let sessionId = arguments["sessionId"] as? String,
          let name = arguments["workoutName"] as? String,
          let json = arguments["state"] as? [String: Any],
          let data = try? JSONSerialization.data(withJSONObject: json),
          let state: WorkoutActivityAttributes.ContentState = Self.decode(data) else { return false }
    lastState = data
    let content = ActivityContent(state: state, staleDate: state.restEndsAt, relevanceScore: 100)
    if let existing = Self.activity(for: sessionId) {
      var alert: AlertConfiguration?
      if let words = arguments["alert"] as? [String: String] {
        alert = AlertConfiguration(
          title: LocalizedStringResource(stringLiteral: words["title"] ?? ""),
          body: LocalizedStringResource(stringLiteral: words["body"] ?? ""),
          sound: .default
        )
      }
      await existing.update(content, alertConfiguration: alert)
      return true
    }
    for other in Activity<WorkoutActivityAttributes>.activities {
      await other.end(nil, dismissalPolicy: .immediate)
    }
    do {
      _ = try Activity.request(
        attributes: WorkoutActivityAttributes(sessionId: sessionId, workoutName: name),
        content: ActivityContent(state: state, staleDate: nil),
        pushType: nil
      )
      return true
    } catch {
      return false
    }
  }

  /// Ends the activity: with `summary` (a finished workout) it stays half an hour showing it, the
  /// length the HIG suggests; without (discarded, signed out) it goes at once
  /// (`endLiveActivity`).
  @available(iOS 17.0, *)
  private func end(_ arguments: [String: Any]) async {
    let activities = Activity<WorkoutActivityAttributes>.activities
    guard !activities.isEmpty else { return }
    let summary = arguments["summary"] as? [String: Any]
    for activity in activities {
      var state = lastState.flatMap { Self.decode($0) as WorkoutActivityAttributes.ContentState? }
        ?? activity.content.state
      state.isActive = false
      state.restEndsAt = nil
      state.isProcessingIntent = false
      state.isWorkoutEnded = true
      if let summary {
        state.finalDurationSeconds = summary["durationSeconds"] as? Double
        state.finalCompletedSetsCount = summary["completedSetsCount"] as? Int
        state.finalVolumeKg = summary["volumeKg"] as? Double
      }
      await activity.end(
        ActivityContent(state: state, staleDate: nil),
        dismissalPolicy: summary == nil ? .immediate : .after(.now + 30 * 60)
      )
    }
    lastState = nil
  }

  @available(iOS 17.0, *)
  private static func activity(for sessionId: String) -> Activity<WorkoutActivityAttributes>? {
    Activity<WorkoutActivityAttributes>.activities.first {
      $0.attributes.sessionId == sessionId && ($0.activityState == .active || $0.activityState == .stale)
    }
  }

  // MARK: - Buttons

  /// Hands a tap to Dart and waits for it to be done, its push included. Then, if nothing it did
  /// changed what the activity shows, the loading state is still up: the last state Dart sent
  /// takes it down (`pushActiveSession`).
  @available(iOS 17.0, *)
  private func forward(_ action: [String: Any]) async {
    await waitForDart()
    await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
      var finished = false
      let finish = {
        guard !finished else { return }
        finished = true
        done.resume()
      }
      activity.invokeMethod("action", arguments: action) { _ in finish() }
      Task {
        try? await Task.sleep(nanoseconds: Self.readyTimeout)
        finish()
      }
    }
    await clearLoading()
  }

  private func waitForDart() async {
    guard !dartReady else { return }
    await withCheckedContinuation { (waiter: CheckedContinuation<Void, Never>) in
      readyWaiters.append(waiter)
      Task {
        try? await Task.sleep(nanoseconds: Self.readyTimeout)
        // Not ready in time (Dart failed to start, or has no workout): give up on every tap
        // still waiting, which then only takes its loading state down.
        self.readyWaiters.forEach { $0.resume() }
        self.readyWaiters.removeAll()
      }
    }
  }

  @available(iOS 17.0, *)
  private func clearLoading() async {
    for activity in Activity<WorkoutActivityAttributes>.activities where activity.content.state.isProcessingIntent {
      var state = lastState.flatMap { Self.decode($0) as WorkoutActivityAttributes.ContentState? }
        ?? activity.content.state
      state.isProcessingIntent = false
      await activity.update(ActivityContent(state: state, staleDate: state.restEndsAt, relevanceScore: 100))
    }
  }

  // MARK: - JSON

  /// Dart's JSON, dates as seconds since 1970.
  nonisolated private static func decode<T: Decodable>(_ data: Data) -> T? {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return try? decoder.decode(T.self, from: data)
  }
}

@available(iOS 17.0, *)
extension WorkoutActivityChannel: LiveActivityIntentHandling {
  func completeSet(id: String) async {
    await forward(["type": "completeSet", "setId": id])
  }

  func adjustLastSetReps(id: String, delta: Int) async {
    await forward(["type": "adjustLastSetReps", "setId": id, "delta": delta])
  }

  func adjustRest(by seconds: Int) async {
    await forward(["type": "adjustRest", "seconds": seconds])
  }

  func skipRest() async {
    await forward(["type": "skipRest"])
  }

  func completeWorkout() async {
    await forward(["type": "completeWorkout"])
  }
}
