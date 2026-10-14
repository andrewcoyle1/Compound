//
//  TodaysWorkoutCardLabel.swift
//  Compound
//
//  Created by Andrew Coyle on 13/03/2026.
//

import SwiftUI

struct TodaysWorkoutCardLabel: View {

    let template: WorkoutTemplateModel
    /// Where the workout sits in the block and how long it takes; the exercise count without one.
    var subtitle: String?
    /// The first few exercises' targets, e.g. "Bench Press · 102.5 kg × 8".
    var targets: [String] = []

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: -Spacing.xl) {
                ForEach(template.exercises.prefix(4)) { exercise in
                    exerciseCircle(exercise: exercise.exercise)
                }
            }
            Divider()
            TodaysWorkoutCardFooter(
                systemImage: Symbol.workout,
                tint: .accentColor,
                title: template.name,
                subtitle: subtitle ?? String(AttributedString(localized: "^[\(template.exercises.count) exercise](inflect: true)").characters),
                showsChevron: true
            )
            if !targets.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    ForEach(targets, id: \.self) { target in
                        Text(target)
                            .font(.rowDetail)
                            .foregroundStyle(.secondary)
                            // Wraps at the accessibility sizes rather than cutting the weight off.
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    }
                }
                .padding(.top, Spacing.xs)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Targets: \(targets.joined(separator: ", "))"))
            }
        }
        .todaysWorkoutCardSurface()
    }

    private func exerciseCircle(exercise: ExerciseModel) -> some View {
        ZStack {
            Circle()
                .fill(.canvas)

            ExerciseImageView(
                name: exercise.name,
                imageName: exercise.imageURL,
                clipShape: AnyShape(Circle())
            )
        }
        // Up to 100 pt, and smaller when four no longer fit across the card.
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 100, maxHeight: 100)
        .overlay(Circle().stroke(.surface, lineWidth: 2))
        .accessibilityHidden(true)
    }
}

struct WorkoutCompletedCard: View {

    let template: WorkoutTemplateModel

    var body: some View {
        VStack {
            Spacer()
            TodaysWorkoutCardFooter(
                systemImage: Symbol.success,
                tint: .success,
                title: template.name,
                subtitle: String(localized: "Completed today"),
                showsChevron: false
            )
        }
        .todaysWorkoutCardSurface()
    }
}

/// Today's finished workout, with what it came to. Tapping it opens the session.
struct WorkoutSummaryCard: View {

    let title: String
    let summary: TodaysWorkoutCardPresenter.SessionSummary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TodaysWorkoutCardFooter(
                systemImage: Symbol.success,
                tint: .success,
                title: title,
                subtitle: summary.figures,
                showsChevron: true
            )
            if let records = summary.records {
                Label {
                    Text(records)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                } icon: {
                    Image(systemName: Symbol.personalRecord)
                        .foregroundStyle(.personalRecord)
                }
                .font(.rowDetail)
            }
        }
        .todaysWorkoutCardSurface()
    }
}

struct RestDayCard: View {

    var body: some View {
        VStack {
            Spacer()
            TodaysWorkoutCardFooter(
                systemImage: Symbol.restDay,
                tint: .accentColor,
                title: String(localized: "Rest Day"),
                subtitle: String(localized: "Recovery is part of the process."),
                showsChevron: false
            )
        }
        .todaysWorkoutCardSurface()
    }
}

/// The glyph, title and subtitle along the bottom of each of the three cards. The title is drawn
/// in `.primary` explicitly: the card is a button, and a button would otherwise tint it.
private struct TodaysWorkoutCardFooter: View {
    let systemImage: String
    let tint: Color
    let title: String
    let subtitle: String
    let showsChevron: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: systemImage)
                .iconSize(.medium)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.sectionTitle)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
            // Wraps at the accessibility sizes rather than cutting "Recovery is part of the process." short.
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.forward")
                    .font(.rowDetail.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    /// Fills the row's width, so the whole row is the tap target.
    func todaysWorkoutCardSurface() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
    }
}

#Preview("Today's Workout") {
    List {
        Section {
            TodaysWorkoutCardLabel(
                template: .mock,
                subtitle: "Week 3 of 5 · Day 2 · ~55 min",
                targets: ["Barbell Bench Press · 102.5 kg × 8", "Dumbbell Fly · 14 kg × 12"]
            )
        }
        Section {
            WorkoutSummaryCard(
                title: "Push",
                summary: .init(figures: "52:10 · 18 sets · 12,400 kg", records: "2 PRs · Barbell Bench Press 100 kg × 5")
            )
        }
        Section { WorkoutCompletedCard(template: .mock) }
        Section { RestDayCard() }
    }
}
