//
//  SetDetailRow.swift
//  DialedIn
//
//  Created by Andrew Coyle on 19/10/2025.
//

import SwiftUI

struct SetDetailRow: View {
    let set: WorkoutSetModel
    let index: Int
    let trackingMode: TrackingMode

    /// A left/right pair shares its number and is told apart by the marker, so three sets a side
    /// read 1L, 1R, 2L, 2R rather than 1 through 4.
    private var label: String {
        String(localized: "Set \(String(describing: index))\(set.side?.initial ?? "")")
    }

    var body: some View {
        HStack {
            // Set number
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            
            // Set details based on tracking mode
            HStack(spacing: 16) {
                switch trackingMode {
                case .weightReps:
                    if let weight = set.weightKg, let reps = set.reps {
                        HStack(spacing: 4) {
                            Text("\(String(format: "%.1f", weight)) kg")
                            Text("×")
                                .foregroundStyle(.secondary)
                            Text("\(reps) reps")
                        }
                    }
                    
                case .repsOnly:
                    if let reps = set.reps {
                        Text("\(reps) reps")
                    }
                    
                case .timeOnly:
                    if let duration = set.durationSec {
                        Text(formatSeconds(duration))
                    }
                    
                case .distanceTime:
                    HStack(spacing: 8) {
                        if let distance = set.distanceMeters {
                            Text("\(String(format: "%.0f", distance)) m")
                        }
                        if let duration = set.durationSec {
                            Text(formatSeconds(duration))
                        }
                    }
                }
                
                Spacer()
                
                if let rpe = set.rpe {
                    HStack(spacing: 2) {
                        Text("RPE")
                            .font(.caption2)
                        Text(String(format: "%.1f", rpe))
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                
                if set.isWarmup {
                    Text("W")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .font(.subheadline)
    }
    
    private func formatSeconds(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        
        if minutes > 0 {
            return String(localized: "\(String(describing: minutes))m \(String(describing: remainingSeconds))s")
        } else {
            return "\(seconds)s"
        }
    }
}

#Preview {
    List {
        SetDetailRow(
            set: WorkoutSetModel.mock,
            index: 1,
            trackingMode: TrackingMode.weightReps
        )
    }
}
