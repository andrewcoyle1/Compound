//
//  WorkoutRestSharedStateTests.swift
//  CompoundUnitTests
//

import Testing

/// The parent of every suite that drives a real `HKWorkoutManager` or requests a real `Activity`.
///
/// Those suites share state the runner cannot partition: the rest end time lives in the app
/// group (`SharedWorkoutStorage`), which the intent handler reads back as a rest in progress, and
/// ActivityKit is one system service that has answered nil to two suites requesting at once.
/// `.serialized` reaches only the suite it is on, so the sharing suites are nested here, where it
/// is applied to all of them: `HKWorkoutManagerRestTests`, `HKWorkoutManagerRestAlertTests`, `HKWorkoutManagerPauseTests`,
/// `LiveActivityIntentHandlerTests`, `LiveActivityScenarioTests` and `LiveActivityManagerTests`,
/// each in its own file.
@Suite(.serialized)
enum WorkoutRestSharedStateTests { }
