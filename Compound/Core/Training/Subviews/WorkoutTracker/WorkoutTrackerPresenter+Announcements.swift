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

extension ActiveWorkout {

    /// "100 kilograms, 8 reps", "12 reps", "1:30": a set's figures as VoiceOver reads them, units
    /// in words; `nil` while the set holds none.
    static func spokenFigures(
        of set: WorkoutSetModel,
        trackingMode: TrackingMode,
        unit: ExerciseWeightUnit,
        distanceUnit: ExerciseDistanceUnit,
        locale: Locale = .autoupdatingCurrent
    ) -> String? {
        var parts: [String] = []
        switch trackingMode {
        case .weightReps, .repsOnly:
            if trackingMode == .weightReps, let weightKg = set.loadKg, weightKg > 0 {
                parts.append(spokenWeight(kg: weightKg, unit: unit, locale: locale))
            }
            if let reps = set.reps { parts.append(Format.reps(reps, locale: locale)) }
        case .timeOnly, .distanceTime:
            if let figures = figures(of: set, trackingMode: trackingMode, unit: unit, distanceUnit: distanceUnit) {
                parts.append(figures)
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// "Set 2, next to log, 100 kilograms, 8 reps": a set row read as one VoiceOver container
    /// (a11y.md M4), so the Containers rotor moves set by set and each says where it stands.
    static func rowSpokenLabel(name: String, state: SetRowState?, figures: String?) -> String {
        let status: String? = switch state {
        case .current?: String(localized: "next to log")
        case .done?: String(localized: "logged")
        case .upcoming?: String(localized: "upcoming")
        case nil: nil
        }
        return [name, status, figures].compactMap { $0 }.joined(separator: ", ")
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
    /// a rest, Next or a tap on the strip.
    func onCurrentExerciseChanged(from old: String?, to new: String?) {
        guard let new, new != old,
              let exercise = workoutSession.exercises.first(where: { $0.id == new }) else { return }
        announce(TrackerAnnouncement(text: String(localized: "Now: \(exercise.name)"), priority: .low))
    }

    /// Every rest that runs out while the screen is up is announced, whatever the sound and
    /// vibration settings: with both off it was the one change that said nothing at all. A
    /// skipped rest posts nothing here; the person skipping it knows.
    func announceRestOver() {
        announce(TrackerAnnouncement(text: String(localized: "Rest over"), priority: .high))
    }

    func announce(_ announcement: TrackerAnnouncement) {
        TrackerAnnouncer.post(announcement)
    }

    // MARK: - The bottom button's names (a11y.md S3, S5)

    /// "Log set 2": the button's words without the figures, which is what fits at accessibility
    /// text sizes. VoiceOver still reads the whole title.
    var primarySlotShortTitle: String {
        primarySlotTitle.components(separatedBy: " · ").first ?? primarySlotTitle
    }

    /// What Voice Control answers to. The title changes with every keystroke in the set's fields;
    /// these do not.
    var primarySlotInputLabels: [String] {
        switch primarySlot {
        case .log?: [primarySlotShortTitle, String(localized: "Log set"), String(localized: "Log")]
        case .skipRest?: [String(localized: "Skip rest"), String(localized: "Skip")]
        case .next?: [primarySlotTitle, String(localized: "Next")]
        case .finish?: [String(localized: "Finish Workout"), String(localized: "Finish")]
        case .resume?: [String(localized: "Resume Workout"), String(localized: "Resume")]
        case nil: []
        }
    }
}
