//
//  WorkoutTemplateRow.swift
//  Compound
//
//  Created by Andrew Coyle on 15/03/2026.
//

import SwiftUI

struct WorkoutTemplateRow: View {
    
    var workoutTemplate: WorkoutTemplateModel
    /// A chip on the name's line, so it never narrows the exercise list below.
    var badge: LocalizedStringKey?
    
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

    /// Primary muscles first, then secondary, each by name, so the row reads the same every time.
    var muscleTags: [(muscle: Muscles, target: MuscleTargetType)] {
        muscleGroups
            .map { (muscle: $0.key, target: $0.value) }
            .sorted { ($0.target == .primary ? 0 : 1, $0.muscle.name) < ($1.target == .primary ? 0 : 1, $1.muscle.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text(workoutTemplate.name)
                    .font(.rowTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                if let badge {
                    Chip(badge)
                }
            }
            if !workoutTemplate.exercises.isEmpty {
                Text(caption)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                ScrollView(.horizontal) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(muscleTags, id: \.muscle) { tag in
                            MuscleChip(muscle: tag.muscle, target: tag.target)
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
