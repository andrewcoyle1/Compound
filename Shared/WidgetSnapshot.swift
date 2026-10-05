//
//  WidgetSnapshot.swift
//  Compound
//
//  What the home-screen widgets show, written by the app into the App Group's UserDefaults on
//  every session end and goal change, and read by the widget extension's timeline provider.
//  Compiled into both targets, so it only uses Foundation and WidgetKit.
//

import Foundation
import WidgetKit

struct WidgetSnapshot: Codable, Equatable {

    struct TodaysWorkout: Codable, Equatable {
        var name: String
        var exerciseCount: Int
        var isRestDay: Bool
        var isCompleted: Bool
    }

    /// Today's day plan, for `day` only.
    var todaysWorkout: TodaysWorkout?
    /// What the queue holds for any later day: the schedule only moves when a workout is logged,
    /// so this stays right until the app writes again. Nil in snapshots from before it existed.
    var upcomingWorkout: TodaysWorkout?
    /// Start of the day `todaysWorkout` belongs to.
    var day: Date
    var currentStreak: Int
    /// Finished sessions in the calendar week containing `day`.
    var sessionsThisWeek: Int
    var weeklyGoal: Int
    var updatedAt: Date

    /// Today's workout as of `date`: the day it was written for shows `todaysWorkout`, any later
    /// day the upcoming one, rather than yesterday's plan or nothing until a workout is logged.
    func todaysWorkout(on date: Date, calendar: Calendar = .current) -> TodaysWorkout? {
        if calendar.isDate(date, inSameDayAs: day) { return todaysWorkout }
        return date > day ? upcomingWorkout : nil
    }

    /// Sessions this week as of `date`: zero once a new week has started.
    func sessionsThisWeek(on date: Date, calendar: Calendar = .current) -> Int {
        calendar.isDate(date, equalTo: day, toGranularity: .weekOfYear) ? sessionsThisWeek : 0
    }

    /// How full the weekly ring is, 0 to 1.
    func weeklyProgress(on date: Date, calendar: Calendar = .current) -> Double {
        guard weeklyGoal > 0 else { return 1 }
        return min(max(Double(sessionsThisWeek(on: date, calendar: calendar)) / Double(weeklyGoal), 0), 1)
    }

    /// Nothing written yet: signed out, or the app has not finished a session since install.
    static func empty(now: Date = Date()) -> WidgetSnapshot {
        WidgetSnapshot(todaysWorkout: nil, upcomingWorkout: nil, day: now, currentStreak: 0, sessionsThisWeek: 0, weeklyGoal: 3, updatedAt: now)
    }

    /// Gallery and placeholder data.
    static func placeholder(now: Date = Date()) -> WidgetSnapshot {
        WidgetSnapshot(
            todaysWorkout: TodaysWorkout(name: "Push Day", exerciseCount: 6, isRestDay: false, isCompleted: false),
            upcomingWorkout: nil,
            day: now,
            currentStreak: 12,
            sessionsThisWeek: 2,
            weeklyGoal: 4,
            updatedAt: now
        )
    }
}

/// The App Group slot the snapshot lives in.
enum WidgetSnapshotStore {

    static let key = "widget.snapshot.v1"

    /// `compound://workout`, which the tab bar turns into the tracker (or the Dashboard's today
    /// card when nothing is under way).
    static let workoutURL = URL(string: "compound://workout")!

    /// `compound://tab/training`, where the streak and the weekly goal are counted from.
    static let trainingURL = URL(string: "compound://tab/training")!

    static func read(from defaults: UserDefaults? = SharedWorkoutStorage.sharedDefaults) -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Writes and asks WidgetKit to reload, but only when something the widgets show changed.
    static func write(_ snapshot: WidgetSnapshot, to defaults: UserDefaults? = SharedWorkoutStorage.sharedDefaults) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        var previous = read(from: defaults)
        previous?.updatedAt = snapshot.updatedAt
        defaults.set(data, forKey: key)
        if previous != snapshot {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// On sign-out, so the home screen stops showing the previous account.
    static func clear(from defaults: UserDefaults? = SharedWorkoutStorage.sharedDefaults) {
        guard let defaults, defaults.data(forKey: key) != nil else { return }
        defaults.removeObject(forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct WidgetSnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

enum WidgetSnapshotTimeline {

    /// One entry now and one at the next midnight, where the views move on to the upcoming workout
    /// and, on a new week, drop the session count. Reloaded with `.atEnd`, so the provider runs again after
    /// midnight and every write from the app reloads it sooner.
    static func entries(
        snapshot: WidgetSnapshot?,
        now: Date,
        calendar: Calendar = .current
    ) -> [WidgetSnapshotEntry] {
        let snapshot = snapshot ?? .empty(now: now)
        var entries = [WidgetSnapshotEntry(date: now, snapshot: snapshot)]
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            entries.append(WidgetSnapshotEntry(date: midnight, snapshot: snapshot))
        }
        return entries
    }
}
