//
//  TemplateExercisePlanDetails.swift
//  Compound
//
//  Under a template exercise's row: the week's targets and the plan's own columns, read-only.
//  Each part shows only when the plan sets it.
//

import SwiftUI

struct TemplateExercisePlanDetails: View {
    let exercise: WorkoutTemplateExercise
    /// "Week 3 · 3 sets · 8–10 · RIR 1".
    let weekSummary: String
    /// "Superset A", nil outside a superset.
    let supersetLabel: String?
    let alternativeNames: [String]

    /// "3 warm-ups · Rest 2:00". Automatic warm-ups and rest say nothing.
    private var setup: String? {
        let parts = [
            exercise.warmupSetCount.map { String(localized: "\($0) warm-ups") },
            exercise.restSeconds.flatMap { $0 > 0 ? String(localized: "Rest \(Format.duration(TimeInterval($0)))") : nil }
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var notes: String? {
        exercise.notes.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(weekSummary)
                .font(.rowDetail)
                .foregroundStyle(.secondary)
            if let supersetLabel {
                Chip(supersetLabel, systemImage: Symbol.superset, tint: .superset)
            }
            if let setup {
                Text(setup)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
            if let notes {
                labelled("Plan notes", notes)
            }
            if !alternativeNames.isEmpty {
                labelled("Alternatives", alternativeNames.formatted(.list(type: .and)))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func labelled(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(.label)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.rowDetail)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let exercise: WorkoutTemplateExercise = {
        var exercise = WorkoutTemplateExercise.mock
        exercise.warmupSetCount = 3
        exercise.restSeconds = 120
        exercise.notes = "Pause for a second at the bottom."
        return exercise
    }()
    List {
        TemplateExercisePlanDetails(
            exercise: exercise,
            weekSummary: "Week 3 · 3 sets · 8–10 · RIR 1",
            supersetLabel: "Superset A",
            alternativeNames: ["Incline Dumbbell Press", "Machine Chest Press"]
        )
    }
}
