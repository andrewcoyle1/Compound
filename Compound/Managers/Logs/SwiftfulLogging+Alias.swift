//
//  SwiftfulLogging+Alias.swift
//  Compound
//
//  Created by Andrew Coyle on 29/01/2026.
//

import SwiftfulLogging
import SwiftfulLoggingMixpanel
import Mixpanel
import SwiftfulLoggingFirebaseAnalytics
import SwiftfulLoggingFirebaseCrashlytics

typealias LogManager = SwiftfulLogging.LogManager
typealias LoggableEvent = SwiftfulLogging.LoggableEvent
typealias LogType = SwiftfulLogging.LogType
typealias LogService = SwiftfulLogging.LogService
typealias AnyLoggableEvent = SwiftfulLogging.AnyLoggableEvent
typealias ConsoleService = SwiftfulLogging.ConsoleService
typealias MixpanelService = SwiftfulLoggingMixpanel.MixpanelService
typealias FirebaseAnalyticsService = SwiftfulLoggingFirebaseAnalytics.FirebaseAnalyticsService
typealias FirebaseCrashlyticsService = SwiftfulLoggingFirebaseCrashlytics.FirebaseCrashlyticsService

extension MixpanelService {
    /// The Mixpanel project stores its data in the EU, which only accepts events sent to the EU
    /// endpoint. Events queue until the first flush, so pointing the instance there straight after
    /// `init` loses none.
    init(euToken token: String, loggingEnabled: Bool = false) {
        self.init(token: token, loggingEnabled: loggingEnabled)
        Mixpanel.mainInstance().serverURL = "https://api-eu.mixpanel.com"
    }
}

extension CoreInteractor {
    // MARK: LogManager
    
    func identifyUser(userId: String, name: String?, email: String?) {
        logManager.identifyUser(userId: userId, name: name, email: email)
    }
    
    func addUserProperties(dict: [String: Any], isHighPriority: Bool) {
        logManager.addUserProperties(dict: dict, isHighPriority: isHighPriority)
    }
    
    func deleteUserProfile() {
        logManager.deleteUserProfile()
    }
    
    func trackEvent(eventName: String, parameters: [String: Any]? = nil, type: LogType = .analytic) {
        logManager.trackEvent(eventName: eventName, parameters: parameters, type: type)
    }
    
    func trackEvent(event: AnyLoggableEvent) {
        logManager.trackEvent(event: event)
    }
    
    func trackEvent(event: LoggableEvent) {
        logManager.trackEvent(event: event)
    }
    
    func trackScreenEvent(event: LoggableEvent) {
        logManager.trackScreenView(event: event)
    }

}
