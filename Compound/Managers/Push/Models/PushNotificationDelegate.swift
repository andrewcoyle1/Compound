//
//  PushNotificationDelegate.swift
//  Compound
//
//  Created by Andrew Coyle on 23/02/2026.
//

import Foundation
import UserNotifications

struct PushNotificationDelegate {
    let identifier: String
    let title: String
    let subtitle: String
    let triggerDate: Date
    let sound: Bool
    let badge: Int?
    let repeats: Bool
    let interruptionLevel: UNNotificationInterruptionLevel

    init(
        identifier: String,
        title: String,
        subtitle: String,
        triggerDate: Date,
        sound: Bool = true,
        badge: Int? = nil,
        repeats: Bool = false,
        interruptionLevel: UNNotificationInterruptionLevel = .active
    ) {
        self.identifier = identifier
        self.title = title
        self.subtitle = subtitle
        self.triggerDate = triggerDate
        self.sound = sound
        self.badge = badge
        self.repeats = repeats
        self.interruptionLevel = interruptionLevel
    }

    /// With `sound` off it is still delivered, as a silent banner.
    var content: UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = subtitle
        content.sound = sound ? .default : nil
        content.badge = badge.map { NSNumber(value: $0) }
        content.interruptionLevel = interruptionLevel
        return content
    }

    var trigger: UNCalendarNotificationTrigger {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
    }
}
