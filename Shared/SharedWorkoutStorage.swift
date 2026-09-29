//
//  SharedWorkoutStorage.swift
//  DialedIn
//
//  Created by Andrew Coyle on 17/10/2025.
//

import Foundation

/// Shared storage for workout data that needs to be accessed by both the main app and widget extension
public struct SharedWorkoutStorage {
    private static let appGroupIdentifier = "group.com.dialedin.app"
    private static let restEndTimeKey = "workout.rest.endTime"
    private static let hkStartedSessionIdKey = "workout.hk.started.sessionId"
    
    static var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }
    
    /// Get the current rest end time
    public static var restEndTime: Date? {
        get {
            guard let defaults = sharedDefaults,
                  let timestamp = defaults.object(forKey: restEndTimeKey) as? TimeInterval else {
                return nil
            }
            return Date(timeIntervalSince1970: timestamp)
        }
        set {
            guard let defaults = sharedDefaults else { return }
            if let newValue = newValue {
                defaults.set(newValue.timeIntervalSince1970, forKey: restEndTimeKey)
            } else {
                defaults.removeObject(forKey: restEndTimeKey)
            }
        }
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
        get {
            guard let defaults = sharedDefaults else { return nil }
            return defaults.string(forKey: hkStartedSessionIdKey)
        }
        set {
            guard let defaults = sharedDefaults else { return }
            if let newValue {
                defaults.set(newValue, forKey: hkStartedSessionIdKey)
            } else {
                defaults.removeObject(forKey: hkStartedSessionIdKey)
            }
        }
    }
    
    /// Clear the recorded HK started session id.
    public static func clearHKStartedSessionId() {
        hkStartedSessionId = nil
    }
}
