//
//  TrainingProgramHeader.swift
//  DialedIn
//
//  Created by Andrew Coyle on 15/03/2026.
//

import SwiftUI

struct TrainingProgramHeader: View {
    
    var program: TrainingProgram
    var isDeloadCycle: Bool = false
    var periodisationPhase: PeriodisationPhase?
    
    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(Color(hex: program.colour).opacity(0.2))
                Image(systemName: program.icon)
                    .foregroundStyle(Color(hex: program.colour))
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(program.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                HStack(spacing: 6) {
                    if isDeloadCycle == true {
                        Text("Deload Week")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                    if let phase = periodisationPhase {
                        Text(phase.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                    Text("\(program.workoutTemplates.filter { !$0.exercises.isEmpty }.count) workouts")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                }
            }
        }
    }
}

#Preview {
    List {
        DisclosureGroup { } label: {
            TrainingProgramHeader(program: .mock)
        }
    }
}
