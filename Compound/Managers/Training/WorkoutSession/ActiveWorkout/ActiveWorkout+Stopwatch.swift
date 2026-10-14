//
//  ActiveWorkout+Stopwatch.swift
//  Compound
//
//  A timed hold's stopwatch, as a rule: start, stop and what it reads, with the clock passed in.
//  A `timeOnly` row (a plank, a dead hang) shows it beside its time field (`SetStopwatch`).
//

import Foundation

extension ActiveWorkout {

    /// Counts up from a tap. With a target, which is what the set was held for last time, it also
    /// counts down to that. Stopping answers the whole seconds held, which the row writes to the
    /// set's `durationSec`; it never logs the set.
    struct Stopwatch: Equatable {
        private(set) var startedAt: Date?
        var targetSeconds: Int?

        init(targetSeconds: Int? = nil) {
            self.targetSeconds = targetSeconds
        }

        var isRunning: Bool { startedAt != nil }

        /// Starts counting from `now`. A second start while running changes nothing.
        mutating func start(at now: Date) {
            guard startedAt == nil else { return }
            startedAt = now
        }

        /// Stops, answering the seconds held to the nearest second. `nil` when it was not running,
        /// or for a stop under half a second, so a double tap writes nothing into the set.
        mutating func stop(at now: Date) -> Int? {
            guard let startedAt else { return nil }
            self.startedAt = nil
            let seconds = Int(now.timeIntervalSince(startedAt).rounded())
            return seconds > 0 ? seconds : nil
        }

        /// Whole seconds since the start, as `Text(timerInterval:)` shows them; 0 when stopped.
        func elapsed(at now: Date) -> Int {
            startedAt.map { max(0, Int(now.timeIntervalSince($0))) } ?? 0
        }

        /// Seconds left to the target, never below zero; `nil` without a target or when stopped.
        func remaining(at now: Date) -> Int? {
            guard isRunning, let targetSeconds else { return nil }
            return max(0, targetSeconds - elapsed(at: now))
        }

        /// From the start to the target, for a countdown; `nil` without a target or when stopped.
        var targetInterval: ClosedRange<Date>? {
            guard let startedAt, let targetSeconds, targetSeconds > 0 else { return nil }
            return startedAt...startedAt.addingTimeInterval(TimeInterval(targetSeconds))
        }
    }
}
