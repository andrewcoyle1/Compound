//
//  SwiftfulUtilities+Alias.swift
//  DialedIn
//
//  Created by Andrew Coyle on 21/02/2026.
//

import SwiftfulUtilities

typealias Utilities = SwiftfulUtilities.Utilities
typealias LocalNotifications = SwiftfulUtilities.LocalNotifications
typealias AppTrackingTransparencyHelper = SwiftfulUtilities.AppTrackingTransparencyHelper
typealias EventKitHelper = SwiftfulUtilities.EventKitHelper
typealias AppStoreRatingsHelper = SwiftfulUtilities.AppStoreRatingsHelper
typealias AnyNotificationContent = SwiftfulUtilities.AnyNotificationContent
typealias NotificationTriggerOption = SwiftfulUtilities.NotificationTriggerOption

// MARK: - Privacy

extension Utilities {

    /// Keys of `eventParameters` that must never leave the device. System uptime is a
    /// required-reason API (system boot time), and every allowed reason forbids sending it, or
    /// anything derived from it, off-device. See `SupportingFiles/PrivacyInfo.xcprivacy`.
    static let onDeviceOnlyParameterKeys: Set<String> = ["utility_system_uptime_days"]

    /// `eventParameters` minus what may not be sent to analytics.
    static var offDeviceEventParameters: [String: Any] {
        eventParameters.filter { !onDeviceOnlyParameterKeys.contains($0.key) }
    }
}
