//
//  SwiftfulGamification+Alias.swift
//  Compound
//
//  Created by Andrew Coyle on 25/02/2026.
//

import SwiftUI
import Firebase

import SwiftfulGamification
import SwiftfulGamificationFirebase

typealias StreakManager = SwiftfulGamification.StreakManager
typealias StreakConfiguration = SwiftfulGamification.StreakConfiguration
typealias GamificationLogger = SwiftfulGamification.GamificationLogger
typealias CurrentStreakData = SwiftfulGamification.CurrentStreakData
typealias MockStreakServices = SwiftfulGamification.MockStreakServices
typealias FileManagerStreakPersistence = SwiftfulGamification.FileManagerStreakPersistence

typealias ExperiencePointsManager = SwiftfulGamification.ExperiencePointsManager
typealias ProgressManager = SwiftfulGamification.ProgressManager
typealias FirebaseStreakService = SwiftfulGamificationFirebase.FirebaseRemoteStreakService
typealias FirebaseRemoteProgressService = SwiftfulGamificationFirebase.FirebaseRemoteProgressService
typealias FirebaseRemoteExperiencePointsService = SwiftfulGamificationFirebase.FirebaseRemoteExperiencePointsService

struct ProductionStreakServices: StreakServices {
    let remote: RemoteStreakService
    let local: LocalStreakPersistence

    init(rootCollectionName: String) {
        self.remote = FirebaseStreakService(rootCollectionName: rootCollectionName)
        self.local = FileManagerStreakPersistence()
    }
}

extension GamificationLogType {
    
    var type: LogType {
        switch self {
        case .info:
            return .info
        case .analytic:
            return .analytic
        case .warning:
            return .warning
        case .severe:
            return .severe
        }
    }
}

extension LogManager: @retroactive GamificationLogger {
    public func trackEvent(event: any GamificationLogEvent) {
        trackEvent(eventName: event.eventName, parameters: event.parameters, type: event.type.type)
    }
}

extension CoreInteractor {
    // MARK: GamificationManager

    var currentStreakData: CurrentStreakData {
        streakManager.currentStreakData
    }
}
