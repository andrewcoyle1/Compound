//
//  MicrocycleItemRow.swift
//  DialedIn
//
//  Created by Andrew Coyle on 15/03/2026.
//

import SwiftUI

struct MicrocycleItemRow: View {
    
    let item: MicrocycleItem
        
    var body: some View {
        HStack {
            // Full contrast: a finished day still opens its session, and the checkmark says it is done.
            WorkoutTemplateRow(workoutTemplate: item.workoutTemplate)
            Spacer()
            if item.isToday {
                Chip("Today")
            }
            // A checkmark when done, the skip symbol when skipped. Otherwise a chevron, because the
            // row opens the workout: the empty circle it used to show is `ListRow`'s unchecked option.
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : (item.isSkipped ? Symbol.skip : "chevron.forward"))
                .iconSize(.small)
                .foregroundStyle(item.isCompleted ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: Text {
        if item.isCompleted { return Text("Completed") }
        if item.isSkipped { return Text("Skipped") }
        return item.timing == .future ? Text("Upcoming") : Text("Not started")
    }
}

#Preview {
    List {
        MicrocycleItemRow(item: .mock)
    }
}
