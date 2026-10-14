//
//  SetTargetPlan+Exercise.swift
//  Compound
//
//  The per-exercise half of the plan in the set-target editor: the warm-up and rest choices, the
//  link check, and the line that sums up how the targets vary by week. Pure, so it is tested
//  rather than eyeballed.
//

import Foundation

extension SetTargetPlan {

    // MARK: - Warm-ups and rest

    /// Automatic (nil, the weight-based rule), then a fixed count.
    static let warmupSetChoices: [Int?] = [nil, 0, 1, 2, 3, 4]

    /// Automatic (nil, the exercise and global settings), then 15 s to 10 min in 15 s steps.
    static let restSecondsChoices: [Int?] = [nil] + Array(stride(from: 15, through: 600, by: 15)).map(Optional.some)

    /// The choices with the exercise's own value among them, so an imported 5 warm-ups or 50 s rest
    /// still shows as chosen.
    static func choices(_ choices: [Int?], including value: Int?) -> [Int?] {
        guard let value, !choices.contains(value) else { return choices }
        return [nil] + (choices.compactMap { $0 } + [value]).sorted().map(Optional.some)
    }

    // MARK: - Link

    /// The link as saved: trimmed, and only an `http` or `https` address with a host. Nil for
    /// anything else.
    static func validatedLink(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host(), !host.isEmpty else { return nil }
        return trimmed
    }

    // MARK: - Weekly variation

    /// The microcycles each list of targets covers, and its set count: "Week 1: 2 sets · Weeks 2–8:
    /// 3 sets · From week 9: 4 sets". Each override runs until the next one starts; the last runs on.
    /// Nil when nothing varies.
    static func variationSummary(base: [SetTarget], overrides: [MicrocycleSetTargets]) -> String? {
        let sorted = overrides.sorted { $0.fromMicrocycle < $1.fromMicrocycle }
        guard let first = sorted.first else { return nil }
        var parts: [String] = []
        if first.fromMicrocycle > 1 {
            parts.append(segment(from: 1, through: first.fromMicrocycle - 1, sets: base.count))
        }
        for (index, override) in sorted.enumerated() {
            let through = sorted.indices.contains(index + 1) ? sorted[index + 1].fromMicrocycle - 1 : nil
            parts.append(segment(from: override.fromMicrocycle, through: through, sets: override.setTargets.count))
        }
        return parts.joined(separator: " · ")
    }

    /// "Week 3", "Weeks 2–8", or "From week 9" for the last, which runs on.
    static func weeksTitle(from: Int, through: Int?) -> String {
        guard let through else { return String(localized: "From week \(from)") }
        return from >= through ? String(localized: "Week \(from)") : String(localized: "Weeks \(from)–\(through)")
    }

    private static func segment(from: Int, through: Int?, sets: Int) -> String {
        String(localized: "\(weeksTitle(from: from, through: through)): \(Format.sets(Double(sets)))")
    }
}
