//
//  WorkoutStreakCard.swift
//  DialedIn
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
        DashboardCard(title: String(localized: "Workout Streak")) {
            VStack(alignment: .leading, spacing: 16) {
                streakHeader
                weeklyDotsRow
                Divider()
                streakStats
            }
        }
    }
    
    private var streakHeader: some View {
        HStack(alignment: .center) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(streakAccentColor)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(presenter.workoutStreakCount)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(streakAccentColor)
                Text(presenter.workoutStreakCount == 1 ? String(localized: "day") : String(localized: "days"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            streakBadge
        }
    }

    @ViewBuilder
    private var streakBadge: some View {
        if presenter.isStreakAtRisk {
            Text("At Risk")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.yellow.opacity(0.15))
                .foregroundStyle(Color.yellow)
                .clipShape(Capsule())
        } else if presenter.isStreakActive {
            Text("Active")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.15))
                .foregroundStyle(Color.orange)
                .clipShape(Capsule())
        }
    }

    private var streakAccentColor: Color {
        if presenter.isStreakAtRisk {
            return .yellow
        } else if presenter.isStreakActive {
            return .orange
        }
        return .secondary
    }

    private var weeklyDotsRow: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekdayIndex = calendar.component(.weekday, from: today) - 1
        let startOfWeek = calendar.date(byAdding: .day, value: -weekdayIndex, to: today) ?? today
        let workoutDays = presenter.workoutDaysThisWeek
        let labels = ["S", "M", "T", "W", "T", "F", "S"]

        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                let day = calendar.date(byAdding: .day, value: index, to: startOfWeek) ?? startOfWeek
                let hasWorkout = workoutDays.contains(day)
                let isToday = calendar.isDateInToday(day)
                let isFuture = day > today

                VStack(spacing: 6) {
                    Text(labels[index])
                        .font(.caption2)
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundStyle(isToday ? .primary : .secondary)
                    ZStack {
                        Circle()
                            .foregroundStyle(hasWorkout ? Color.orange : Color(.systemFill))
                            .opacity(hasWorkout ? 1.0 : isFuture ? 0.2 : 0.45)
                        if isToday && !hasWorkout {
                            Circle()
                                .strokeBorder(.primary.opacity(0.35), lineWidth: 1.5)
                        }
                    }
                    .frame(width: 10, height: 10)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var streakStats: some View {
        HStack {
            StatItem(header: String(localized: "Best streak"), value: "\(presenter.longestStreak) days")
            Spacer()
            StatItem(alignment: .trailing, header: String(localized: "Total workouts"), value: "\(presenter.totalWorkouts)")
        }
    }

}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = WorkoutStreakDelegate()
    
    RouterView { router in
        builder.workoutStreakCardView(
            router: router,
            delegate: delegate
        )
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
