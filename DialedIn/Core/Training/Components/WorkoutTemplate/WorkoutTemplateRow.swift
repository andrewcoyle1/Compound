//
//  WorkoutTemplateRow.swift
//  DialedIn
//
//  Created by Andrew Coyle on 15/03/2026.
//

import SwiftUI

struct WorkoutTemplateRow: View {
    
    var workoutTemplate: WorkoutTemplateModel
    
    var caption: String {
        let names = workoutTemplate.exercises.compactMap { exerciseItem -> String? in
            // Assuming each element has an optional `exercise` with a `name` property
            return exerciseItem.exercise.name
        }
        return names.joined(separator: ", ")
    }
    
    var muscleGroups: [Muscles: MuscleTargetType] {
        workoutTemplate.exercises
            .map { $0.exercise.muscleGroups }
            .reduce(into: [:]) { result, dict in
                for (muscle, targetType) in dict {
                    if result[muscle] == nil || targetType == .primary {
                        result[muscle] = targetType
                    }
                }
            }
    }

    var primaryMuscleTags: [Muscles] {
        muscleGroups.compactMap { $0.value == .primary ? $0.key : nil }
    }

    var secondaryMuscleTags: [Muscles] {
        muscleGroups.compactMap { $0.value == .secondary ? $0.key : nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(workoutTemplate.name)
                .font(.headline)
            if !workoutTemplate.exercises.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(primaryMuscleTags, id: \.self) { muscle in
                            Text(muscle.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2), in: Capsule())
                        }
                        ForEach(secondaryMuscleTags, id: \.self) { muscle in
                            Text(muscle.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2), in: Capsule())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }

    }
}

#Preview {
    List {
        WorkoutTemplateRow(workoutTemplate: .mock)
    }
}
