//
//  TodaysWorkoutCardLabel.swift
//  DialedIn
//
//  Created by Andrew Coyle on 13/03/2026.
//

import SwiftUI

struct TodaysWorkoutCardLabel: View {

    let template: WorkoutTemplateModel

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: -Spacing.xl) {
                ForEach(template.exercises.prefix(4)) { exercise in
                    exerciseCircle(exercise: exercise.exercise)
                }
            }
            .frame(maxHeight: .infinity)
            Divider()
            TodaysWorkoutCardFooter(
                systemImage: Symbol.workout,
                tint: .accentColor,
                title: template.name,
                subtitle: String(AttributedString(localized: "^[\(template.exercises.count) exercise](inflect: true)").characters),
                showsChevron: true
            )
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
        // Up to 100 pt, and smaller when the footer's text grows and leaves less of the card.
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
    /// Fills the Dashboard card's content height, so the whole surface is the tap target.
    func todaysWorkoutCardSurface() -> some View {
        padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .cardSurface()
    }
}

#Preview("Today's Workout") {
    List {
        Section {
            TodaysWorkoutCardLabel(template: .mock)
                .frame(height: TodayCard<EmptyView>.contentHeight)
        }
        .frame(height: 240)
        .removeListRowFormatting()
    }
}

#Preview("Tabs") {
    List {
        Section {
            TabView {
                Tab {
                    RestDayCard()
                }
                Tab {
                    WorkoutCompletedCard(template: .mock)
                }
                Tab {
                    TodaysWorkoutCardLabel(template: .mock)
                }
            }
            .tabViewStyle(.page)
        }
        .frame(height: 240)
        .listSectionMargins(.horizontal, 0)
        .removeListRowFormatting()
        .listRowSeparator(.hidden)
    }
}
