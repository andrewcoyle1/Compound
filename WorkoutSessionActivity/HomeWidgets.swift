//
//  HomeWidgets.swift
//  WorkoutSessionActivity
//
//  The home-screen and Lock Screen widgets: Today's Workout, Streak and Weekly Ring. All three
//  read the `WidgetSnapshot` the app writes to the App Group, through one timeline provider.
//

import SwiftUI
import WidgetKit

struct WidgetSnapshotProvider: TimelineProvider {

    func placeholder(in context: Context) -> WidgetSnapshotEntry {
        WidgetSnapshotEntry(date: Date(), snapshot: .placeholder())
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetSnapshotEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(WidgetSnapshotEntry(date: Date(), snapshot: WidgetSnapshotStore.read() ?? .empty()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetSnapshotEntry>) -> Void) {
        let entries = WidgetSnapshotTimeline.entries(snapshot: WidgetSnapshotStore.read(), now: Date())
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Today's Workout

struct TodaysWorkoutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodaysWorkoutWidget", provider: WidgetSnapshotProvider()) { entry in
            TodaysWorkoutWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(WidgetSnapshotStore.workoutURL)
        }
        .configurationDisplayName("Today's Workout")
        .description("Today's session from your program.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodaysWorkoutWidgetView: View {
    let entry: WidgetSnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var workout: WidgetSnapshot.TodaysWorkout? {
        entry.snapshot.todaysWorkout(on: entry.date)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Today", systemImage: "dumbbell.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
                Spacer(minLength: 0)
                Text(workout?.name ?? "No workout planned")
                    .font(.headline)
                    .lineLimit(2)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if family == .systemMedium {
                Spacer()
                Image(systemName: workout?.isCompleted == true ? "checkmark.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var detail: String {
        guard let workout else { return "Open to pick one" }
        if workout.isRestDay { return "Rest day" }
        if workout.isCompleted { return "Done" }
        return workout.exerciseCount == 1 ? "1 exercise" : "\(workout.exerciseCount) exercises"
    }
}

// MARK: - Streak

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StreakWidget", provider: WidgetSnapshotProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Streak")
        .description("Your current training streak.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct StreakWidgetView: View {
    let entry: WidgetSnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                    Text("\(entry.snapshot.currentStreak)")
                        .font(.title3.bold())
                        .minimumScaleFactor(0.5)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(entry.snapshot.currentStreak) day streak")
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Spacer(minLength: 0)
                Text("\(entry.snapshot.currentStreak)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                Text(entry.snapshot.currentStreak == 1 ? "day streak" : "days streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Weekly Ring

struct WeeklyRingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeeklyRingWidget", provider: WidgetSnapshotProvider()) { entry in
            WeeklyRingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weekly Goal")
        .description("Sessions this week against your goal.")
        .supportedFamilies([.systemSmall])
    }
}

struct WeeklyRingWidgetView: View {
    let entry: WidgetSnapshotEntry

    var body: some View {
        let sessions = entry.snapshot.sessionsThisWeek(on: entry.date)
        let goal = entry.snapshot.weeklyGoal
        ZStack {
            Circle()
                .stroke(.tint.opacity(0.2), lineWidth: 12)
            Circle()
                .trim(from: 0, to: entry.snapshot.weeklyProgress(on: entry.date))
                .stroke(.tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(sessions)/\(goal)")
                    .font(.title2.bold())
                Text("this week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sessions) of \(goal) sessions this week")
    }
}

// MARK: - Previews

#Preview("Today", as: .systemMedium) {
    TodaysWorkoutWidget()
} timeline: {
    WidgetSnapshotEntry(date: .now, snapshot: .placeholder())
    WidgetSnapshotEntry(date: .now, snapshot: .empty())
}

#Preview("Streak", as: .accessoryCircular) {
    StreakWidget()
} timeline: {
    WidgetSnapshotEntry(date: .now, snapshot: .placeholder())
}

#Preview("Weekly", as: .systemSmall) {
    WeeklyRingWidget()
} timeline: {
    WidgetSnapshotEntry(date: .now, snapshot: .placeholder())
}
