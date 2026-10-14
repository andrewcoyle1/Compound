//
//  TrackerAnnouncement.swift
//  Compound
//
//  One thing VoiceOver is told on the tracker, and where it goes.
//

import SwiftUI
import Accessibility

/// One thing VoiceOver says.
struct TrackerAnnouncement: Equatable, Sendable {
    typealias Priority = AttributeScopes.AccessibilityAttributes.AnnouncementPriorityAttribute.AnnouncementPriority

    let text: String
    /// `.high` interrupts what is being read; `.low` waits for it, so "Now: Barbell Row" follows
    /// "Set 2 logged" rather than cutting it off.
    var priority: Priority = .default

    @MainActor
    func post() {
        var string = AttributedString(text)
        string.accessibilitySpeechAnnouncementPriority = priority
        AccessibilityNotification.Announcement(string).post()
    }
}

enum TrackerAnnouncer {
    /// Where announcements go. A test binds it to a spy with `$post.withValue`, which holds for
    /// that task alone, so suites running side by side never hear one another.
    @TaskLocal static var post: @MainActor @Sendable (TrackerAnnouncement) -> Void = { $0.post() }
}
