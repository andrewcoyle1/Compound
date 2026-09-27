//
//  TodaysWorkoutCardLabel.swift
//  DialedIn
//
//  Created by Andrew Coyle on 13/03/2026.
//

import SwiftUI

struct TodaysWorkoutCardLabel: View {
    
    @Environment(\.colorScheme) private var colorScheme

    let template: WorkoutTemplateModel
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: -24) {
                ForEach(template.exercises.prefix(4)) { exercise in
                    exerciseCircle(exercise: exercise.exercise)
                }
            }
            .frame(maxHeight: .infinity)
            Divider()
            HStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundStyle(.accent)
                VStack(alignment: .leading) {
                    Text(template.name)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text("\(template.exercises.count) exercise\(template.exercises.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(colorScheme.backgroundPrimary, in: .rect)
        .cornerRadius(24)
        .padding(.bottom)
        .frame(height: 200)
    }
    
    @ViewBuilder
    private func exerciseCircle(exercise: ExerciseModel) -> some View {
        ZStack {
            Circle()
                .fill(Color(uiColor: .secondarySystemBackground))

            ImageLoaderView(
                urlString: exercise.imageURL ?? "SplashScreen",
                resizingMode: .fit,
                clipShape: AnyShape(Circle())
            )
        }
        .frame(width: 100, height: 100)
        .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
    }
}

struct WorkoutCompletedCard: View {
    
    @Environment(\.colorScheme) private var colorScheme

    let template: WorkoutTemplateModel
    
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading) {
                    Text(template.name)
                        .font(.title3.bold())
                    Text("Completed today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(colorScheme.backgroundPrimary, in: .rect)
        .cornerRadius(24)
        .padding(.bottom)
        .frame(height: 200)
    }
}

struct RestDayCard: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "moon.zzz.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text("Rest Day")
                        .font(.title3.bold())
                    Text("Recovery is part of the process.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(colorScheme.backgroundPrimary, in: .rect)
        .cornerRadius(24)
        .padding(.bottom)
        .frame(height: 200)
    }
}

#Preview("Today's Workout") {
    List {
        Section {
            TodaysWorkoutCardLabel(template: .mock)
                .frame(height: 200)
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
