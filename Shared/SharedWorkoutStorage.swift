//
//  SharedWorkoutStorage.swift
//  Compound
//
//  Created by Andrew Coyle on 17/10/2025.
//

import Foundation

/// Shared storage for workout data that needs to be accessed by both the main app and widget extension
public struct SharedWorkoutStorage {
    private static let appGroupIdentifier = "group.com.compound.app"
    private static let restEndTimeKey = "workout.rest.endTime"
    private static let hkStartedSessionIdKey = "workout.hk.started.sessionId"
    
    private static let restStartedAtKey = "workout.rest.startedAt"
    private static let pausedAtKey = "workout.pause.pausedAt"
    private static let pausedDurationKey = "workout.pause.duration"

    static var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }

    /// The App Group's store, as `HKWorkoutManager` and the widget read it.
    static var appGroup: Store { Store(defaults: sharedDefaults) }

    /// What the rest's owner keeps across a relaunch: the rest, the pause and the started HealthKit
    /// session. A value over one `UserDefaults`, so a test can hand a fresh manager a store of its
    /// own, filled in as a killed process would have left it.
    struct Store {
        let defaults: UserDefaults?

        /// When the running rest ends.
        var restEndTime: Date? {
            get { date(forKey: SharedWorkoutStorage.restEndTimeKey) }
            nonmutating set { set(newValue, forKey: SharedWorkoutStorage.restEndTimeKey) }
        }

        /// When the rest began. Kept after it runs out, so the inline timer reads Ready until the
        /// next set; cleared with the rest when it is called off.
        var restStartedAt: Date? {
            get { date(forKey: SharedWorkoutStorage.restStartedAtKey) }
            nonmutating set { set(newValue, forKey: SharedWorkoutStorage.restStartedAtKey) }
        }

        /// When the workout was paused, while it is.
        var pausedAt: Date? {
            get { date(forKey: SharedWorkoutStorage.pausedAtKey) }
            nonmutating set { set(newValue, forKey: SharedWorkoutStorage.pausedAtKey) }
        }

        /// Time spent paused before the current pause.
        var pausedDuration: TimeInterval {
            get { defaults?.double(forKey: SharedWorkoutStorage.pausedDurationKey) ?? 0 }
            nonmutating set { defaults?.set(newValue, forKey: SharedWorkoutStorage.pausedDurationKey) }
        }

        /// The workout session id for which a HealthKit session has been started, so a tracker
        /// minimized and reopened does not start a second one.
        var hkStartedSessionId: String? {
            get { defaults?.string(forKey: SharedWorkoutStorage.hkStartedSessionIdKey) }
            nonmutating set { defaults?.set(newValue, forKey: SharedWorkoutStorage.hkStartedSessionIdKey) }
        }

        private func date(forKey key: String) -> Date? {
            (defaults?.object(forKey: key) as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        }

        private func set(_ date: Date?, forKey key: String) {
            if let date {
                defaults?.set(date.timeIntervalSince1970, forKey: key)
            } else {
                defaults?.removeObject(forKey: key)
            }
        }
    }

    /// Get the current rest end time
    public static var restEndTime: Date? {
        get { appGroup.restEndTime }
        set { appGroup.restEndTime = newValue }
    }

    /// Clear the rest end time
    public static func clearRestEndTime() {
        restEndTime = nil
    }

    // MARK: - HealthKit Session Tracking

    /// The workout session id for which we've already started a HKWorkoutSession.
    /// This helps avoid attempting to start the same HK session multiple times
    /// when the tracker view is minimized and reopened.
    public static var hkStartedSessionId: String? {
        get { appGroup.hkStartedSessionId }
        set { appGroup.hkStartedSessionId = newValue }
    }

    /// Clear the recorded HK started session id.
    public static func clearHKStartedSessionId() {
        hkStartedSessionId = nil
    }

    // MARK: - Legacy store

    /// The suite earlier builds wrote to. The app was never granted it, so it is a store private
    /// to the app, which is why only the app can migrate it.
    static let legacyAppGroupIdentifier = "group.com.dialedin.app"

    /// Moves the running rest and the started HealthKit session out of the store earlier builds
    /// used, so an install that updates mid-workout neither loses its rest nor starts a second
    /// HealthKit session. A value already in `current` wins. The legacy keys are removed either
    /// way, so this does nothing on every launch after the first.
    static func migrateLegacy(from legacy: UserDefaults, to current: UserDefaults) {
        for key in [restEndTimeKey, hkStartedSessionIdKey] {
            guard let value = legacy.object(forKey: key) else { continue }
            if current.object(forKey: key) == nil {
                current.set(value, forKey: key)
            }
            legacy.removeObject(forKey: key)
        }
    }
}
