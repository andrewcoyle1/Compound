//
//  LiveActivityIntentHandling.swift
//  Compound
//
//  The seam a `LiveActivityIntent` reaches the app through
//  (spec: docs/specs/live-activity.md §7.1).
//
//  A `LiveActivityIntent` runs in the app's process: the system launches or wakes the app in the
//  background and calls `perform()` there. So an intent does not need to leave a note in shared
//  storage for a poll to find — it can call the managers directly, through this protocol.
//
//  It lives in `Shared/` because the intents compile into both the app and the widget extension,
//  and only the app registers an implementation. In the widget `current` is nil, which is what
//  the intents' fallback is for.
//

import Foundation

/// The five things the Live Activity can ask the app to do.
///
/// Every action ends with a push of the saved session to the activity, so the app stays the single
/// source of truth for what the activity shows; the intent's optimistic update covers only the gap
/// until that push lands.
@MainActor
protocol LiveActivityIntentHandling: AnyObject {

    /// Log the set with that id from its own target values and start the rest that follows it.
    func completeSet(id: String) async

    /// Correct the reps of a set already logged, while the rest after it is still running.
    func adjustLastSetReps(id: String, delta: Int) async

    /// Lengthen (or shorten) the running rest.
    func adjustRest(by seconds: Int) async

    /// End the running rest now.
    func skipRest() async

    /// Finish the workout the way the tracker's Finish button does.
    func completeWorkout() async
}

/// Where the app parks its handler for the intents to find.
///
/// Weak on purpose: the app owns the handler for as long as it is running, and a strong static
/// would keep a torn-down object — and every manager it holds — alive past that.
@MainActor
enum LiveActivityIntentHandler {
    static weak var current: (any LiveActivityIntentHandling)?
}
