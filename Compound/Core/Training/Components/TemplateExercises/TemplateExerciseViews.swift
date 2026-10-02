//
//  TemplateExerciseViews.swift
//  Compound
//
//  The target-muscle summary and the exercise row that DefineWorkoutView and
//  WorkoutTemplateDetailView both draw. Each screen carried its own copy, and the copies had
//  drifted: only one marked primary muscles by more than a darker fill.
//

import SwiftUI

// MARK: - Target muscles

/// The "Target Muscles" section: one tile per muscle with its planned sets and exercise count.
struct TargetMusclesSection: View {
    let summaries: [TargetMuscleSummary]

    var body: some View {
        Section("Target Muscles") {
            if summaries.isEmpty {
                ListRow(
                    title: String(localized: "You haven't added any exercises yet. Once you add an exercise, target muscles will appear here."),
                    systemImage: Symbol.muscleGroup,
                    tint: .secondary
                )
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: Spacing.s) {
                        ForEach(summaries) { summary in
                            tile(summary)
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }
                .removeListRowFormatting()
                .scrollIndicators(.hidden)
            }
        }
    }

    private func tile(_ summary: TargetMuscleSummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(summary.muscle.name)
                .font(.rowDetail)
                .fontWeight(.semibold)
            Text("Target: \(Format.sets(summary.weightedTargetSets))")
                .font(.label)
                .foregroundStyle(.secondary)
            Text("^[\(summary.exerciseCount) exercise](inflect: true)")
                .font(.label)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .padding(Spacing.m)
        .background(Color.tintedSurface(.secondary), in: .rect(cornerRadius: Radius.m, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Exercise row

/// An exercise in a template: its image, name, set targets and the muscles it trains. The caller
/// makes it tappable.
struct TemplateExerciseRow: View {
    let exercise: WorkoutTemplateExercise

    @ScaledMetric(relativeTo: .body) private var imageSide: CGFloat = 60

    var body: some View {
        // The image goes above the details at accessibility sizes; beside them it left the name a
        // few letters before the ellipsis.
        AdaptiveStack {
            ExerciseImageView(name: exercise.exercise.name, imageName: exercise.exercise.imageURL)
                .frame(width: imageSide, height: imageSide)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(exercise.exercise.name)
                    .font(.rowTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                LazyHGrid(rows: [GridItem(), GridItem()], alignment: .top) {
                    ForEach(exercise.setTargets) { target in
                        SetTargetLabel(target: target)
                    }
                }
                ScrollView(.horizontal) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(
                            exercise.exercise.muscleGroups.sorted { $0.key.name < $1.key.name },
                            id: \.key
                        ) { muscle, target in
                            MuscleChip(muscle: muscle, target: target)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

/// A muscle an exercise trains. Primary and secondary differ by fill, weight and the spoken label,
/// so the difference never rests on colour alone.
struct MuscleChip: View {
    let muscle: Muscles
    let target: MuscleTargetType

    var body: some View {
        Chip(muscle.name, tint: Color.Metric.muscleGroups, isSelected: target == .primary)
            .fontWeight(target == .primary ? .semibold : .regular)
            // Filled means primary here, not chosen.
            .accessibilityRemoveTraits(.isSelected)
            .accessibilityLabel("\(muscle.name), \(target == .primary ? String(localized: "primary") : String(localized: "secondary"))")
    }
}

/// "1  8–12 reps": a set's number in a small badge beside its rep target.
struct SetTargetLabel: View {
    let target: SetTarget

    var body: some View {
        // The number sizes its own badge: a fixed 12pt circle drew over the text beside it once
        // the number outgrew it.
        HStack(spacing: Spacing.xs) {
            Text("\(target.setNumber)")
                .font(.label.weight(.semibold))
                .monospacedDigit()
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                .background(.quaternary, in: .capsule)
            Text(target.repTargetDescription)
                .font(.label)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Set \(target.setNumber), \(target.repTargetDescription)")
    }
}

extension SetTarget {
    /// "8–12 reps", "1–12 reps" when only a ceiling is set, "8+ reps" when only a floor is.
    var repTargetDescription: String {
        switch (minReps, maxReps) {
        case let (min?, max?):
            return String(localized: "\(Format.repRange(min, max)) reps")
        case let (nil, max?):
            return String(localized: "\(Format.repRange(1, max)) reps")
        case let (min?, nil):
            return String(localized: "\(min)+ reps")
        case (nil, nil):
            return String(localized: "No target set")
        }
    }
}

#Preview {
    List {
        TargetMusclesSection(summaries: MuscleVolume.targetSummaries(exercises: WorkoutTemplateExercise.mocks))
        TargetMusclesSection(summaries: [])
        Section("Exercises") {
            ForEach(WorkoutTemplateExercise.mocks) { exercise in
                TemplateExerciseRow(exercise: exercise)
            }
        }
    }
}
