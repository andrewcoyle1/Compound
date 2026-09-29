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
            // A checkmark when done. Otherwise a chevron, because the row opens the workout: the empty
            // circle it used to show is `ListRow`'s unchecked option.
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "chevron.forward")
                .iconSize(.small)
                .foregroundStyle(item.isCompleted ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.isCompleted ? Text("Completed") : Text("Not started"))
    }
}

#Preview {
    List {
        MicrocycleItemRow(item: .mock)
    }
}
