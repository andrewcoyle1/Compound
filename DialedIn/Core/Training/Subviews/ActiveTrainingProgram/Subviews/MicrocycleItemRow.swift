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
            WorkoutTemplateRow(workoutTemplate: item.workoutTemplate)
                .opacity(item.isCompleted ? 0.3 : 1)
            Spacer()
            // The same glyph `ListRow` draws for a checked row: accent when done, empty otherwise.
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
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
