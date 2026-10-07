//
//  WorkoutTrackerPresenter+Announcements.swift
//  Compound
//
//  What VoiceOver is told without moving focus (a11y.md S1): a set logged, a rest run out, and
//  the card moving to another exercise. A sighted user sees each of these; the screen changes
//  under a VoiceOver user's finger and, before this, said nothing. Announcements are spoken only
//  while VoiceOver runs, so nobody else hears them.
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

extension WorkoutTrackerPresenter {

    /// The set logged last and when, which the view watches: a newer one is announced.
    struct LogMark: Equatable {
        let setId: String
        let completedAt: Date
    }

    var latestLogMark: LogMark? {
        guard let set = ActiveWorkout.latestCompletedSet(in: workoutSession.exercises),
              let completedAt = set.completedAt else { return nil }
        return LogMark(setId: set.id, completedAt: completedAt)
    }

    /// "Set 2 logged, 100 kilograms, 8 reps", for a log from the button, the row or the Lock
    /// Screen alike. An undo makes an older set the latest, which is not a log and says nothing.
    func onLatestLogChanged(from old: LogMark?, to new: LogMark?) {
        guard let new, new.completedAt > old?.completedAt ?? .distantPast,
              let exercise = workoutSession.exercises.first(where: { $0.sets.contains { $0.id == new.setId } }),
              let set = exercise.sets.first(where: { $0.id == new.setId }) else { return }
        let units = units(for: exercise)
        announce(TrackerAnnouncement(
            text: ActiveWorkout.correctionSpokenLabel(for: set, in: exercise, unit: units.weightUnit, distanceUnit: units.distanceUnit)
        ))
    }

    /// "Now: Barbell Row", queued behind whatever is being read, as the card moves after a log,
    /// a rest, Next or a tap on Up Next.
    func onCurrentExerciseChanged(from old: String?, to new: String?) {
        guard let new, new != old,
              let exercise = workoutSession.exercises.first(where: { $0.id == new }) else { return }
        announce(TrackerAnnouncement(text: String(localized: "Now: \(exercise.name)"), priority: .low))
    }

    /// Every rest that runs out while the screen is up is announced, whatever the sound and
    /// vibration settings: with both off it was the one change that said nothing at all. A
    /// skipped rest posts nothing here; the person skipping it knows.
    func observeRestOverAnnouncements() async {
        for await _ in NotificationCenter.default.notifications(named: Constants.workoutRestDidComplete) {
            announceRestOver()
        }
    }

    func announceRestOver() {
        announce(TrackerAnnouncement(text: String(localized: "Rest over"), priority: .high))
    }

    private func announce(_ announcement: TrackerAnnouncement) {
        TrackerAnnouncer.post(announcement)
    }
}
