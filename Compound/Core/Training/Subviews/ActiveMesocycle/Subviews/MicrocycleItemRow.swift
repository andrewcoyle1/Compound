//
//  MicrocycleItemRow.swift
//  Compound
//
//  Created by Andrew Coyle on 15/03/2026.
//

import SwiftUI

struct MicrocycleItemRow: View {
    
    let item: MicrocycleItem
        
    var body: some View {
        HStack {
            // Full contrast: a finished day still opens its session, and the checkmark says it is done.
            WorkoutTemplateRow(workoutTemplate: item.workoutTemplate, badge: badge)
            Spacer()
            // The same circle on every day, filled when done. Tapping a rest day ticks it; tapping a
            // workout opens it, and only finishing it ticks it, so a workout is never done unlogged.
            Image(systemName: item.isCompleted ? Symbol.success : (item.isSkipped ? Symbol.skip : "circle"))
                .iconSize(.small)
                .foregroundStyle(item.isCompleted ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(item.canToggleRest ? Text(item.isCompleted ? "Marks the rest day not taken" : "Marks the rest day taken") : Text(verbatim: ""))
    }

    private var badge: LocalizedStringKey? {
        if item.isToday { return "Today" }
        if item.isBeforeStart { return "Not tracked" }
        return nil
    }

    private var accessibilityValue: Text {
        if item.isCompleted { return Text("Completed") }
        if item.isSkipped { return Text("Skipped") }
        if item.isBeforeStart { return Text("Not tracked") }
        return item.timing == .future ? Text("Upcoming") : Text("Not started")
    }
}

#Preview {
    List {
        MicrocycleItemRow(item: .mock)
    }
}
