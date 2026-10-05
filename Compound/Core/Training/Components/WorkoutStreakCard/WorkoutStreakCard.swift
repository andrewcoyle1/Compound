//
//  WorkoutStreakCard.swift
//  Compound
//
//  Created by Andrew Coyle on 13/03/2026.
//

import SwiftUI

struct WorkoutStreakDelegate {
    
}

struct WorkoutStreakCard: View {
    
    @State var presenter: WorkoutStreakPresenter
    let delegate: WorkoutStreakDelegate
    
    var body: some View {
        Section("Weekly Streak") {
            VStack(alignment: .leading, spacing: Spacing.l) {
                streakHeader
                weeklyDotsRow
                Divider()
                streakStats
            }
        }
    }
    
    private var streakHeader: some View {
        HStack(alignment: .center) {
            Image(systemName: Symbol.streak)
                .iconSize(.medium)
                .foregroundStyle(streakAccentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(presenter.weeksText)
                    .font(.display)
                    .foregroundStyle(streakAccentColor)
                Text(presenter.thisWeekText)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            streakBadge
        }
    }

    @ViewBuilder
    private var streakBadge: some View {
        switch presenter.streak.state {
        case .atRisk:
            Chip("At Risk", systemImage: Symbol.warning, tint: .warning)
        case .met:
            Chip("Goal Met", systemImage: Symbol.success, tint: Color.Metric.workouts)
        case .onTrack, .none:
            EmptyView()
        }
    }

    private var streakAccentColor: Color {
        if presenter.streak.state == .atRisk { return .warning }
        return presenter.streak.weeks > 0 ? Color.Metric.workouts : .secondary
    }

    private var weeklyDotsRow: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startOfWeek = presenter.startOfWeek
        let workoutDays = presenter.workoutDaysThisWeek
        // The calendar's own letters, indexed by each day's weekday, so they are localised.
        let labels = calendar.veryShortWeekdaySymbols

        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                let day = calendar.date(byAdding: .day, value: index, to: startOfWeek) ?? startOfWeek
                let hasWorkout = workoutDays.contains(day)
                let isToday = calendar.isDateInToday(day)
                let isFuture = day > today

                VStack(spacing: Spacing.xs) {
                    Text(labels[calendar.component(.weekday, from: day) - 1])
                        .font(.caption2)
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundStyle(isToday ? .primary : .secondary)
                    ZStack {
                        Circle()
                            .foregroundStyle(hasWorkout ? Color.Metric.workouts : Color(.systemFill))
                            .opacity(hasWorkout ? 1.0 : isFuture ? 0.2 : 0.45)
                        if isToday && !hasWorkout {
                            Circle()
                                .strokeBorder(.primary.opacity(0.35), lineWidth: 1.5)
                        }
                    }
                    .frame(width: 10, height: 10)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide)))
                .accessibilityValue(hasWorkout ? Text("Workout logged") : Text("No workout"))
            }
        }
    }

    private var streakStats: some View {
        HStack {
            Stat(value: presenter.bestText, label: String(localized: "Best streak"), size: .small)
            Spacer()
            Stat(value: presenter.totalWorkouts.formatted(), label: String(localized: "Total workouts"), size: .small, alignment: .trailing)
        }
    }

}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = WorkoutStreakDelegate()
    
    RouterView { router in
        List {
            builder.workoutStreakCardView(
                router: router,
                delegate: delegate
            )
        }
    }
}

extension CoreBuilder {
    func workoutStreakCardView(router: AnyRouter, delegate: WorkoutStreakDelegate) -> some View {
        WorkoutStreakCard(
            presenter: WorkoutStreakPresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                )
            ),
            delegate: delegate
        )
    }
}
