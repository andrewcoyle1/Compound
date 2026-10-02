//
//  MesocycleHeader.swift
//  Compound
//
//  Created by Andrew Coyle on 15/03/2026.
//

import SwiftUI

struct MesocycleHeader: View {

    var mesocycle: Mesocycle
    var isDeloadCycle: Bool = false
    var periodisationPhase: PeriodisationPhase?

    @ScaledMetric(relativeTo: .body) private var badgeSide = ControlSize.row

    private var workoutCount: Int {
        mesocycle.workoutTemplates.filter { !$0.exercises.isEmpty }.count
    }

    var body: some View {
        HStack(spacing: Spacing.m) {
            ZStack {
                Circle()
                    .fill(Color.tintedSurface(Color(hex: mesocycle.colour)))
                Image(systemName: mesocycle.icon)
                    .foregroundStyle(Color(hex: mesocycle.colour))
            }
            .frame(width: badgeSide, height: badgeSide)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(mesocycle.name)
                    .font(.sectionTitle)
                    .foregroundStyle(.primary)
                HStack(spacing: Spacing.xs) {
                    if isDeloadCycle {
                        Chip("Deload Week", tint: .secondary)
                    }
                    if let phase = periodisationPhase {
                        Chip(phase.label, tint: .secondary)
                    }
                    Text("^[\(workoutCount) workout](inflect: true)")
                        .font(.label)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        DisclosureGroup { } label: {
            MesocycleHeader(mesocycle: .mock)
        }
    }
}
