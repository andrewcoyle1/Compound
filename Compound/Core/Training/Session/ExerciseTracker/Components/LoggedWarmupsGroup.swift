//
//  LoggedWarmupsGroup.swift
//  Compound
//
//  Done warm-ups folded into one line.
//

import SwiftUI

/// Done warm-ups fold into one line, so the table starts at the work, and open on a tap to be
/// corrected.
struct LoggedWarmupsGroup<Row: View>: View {

    let sets: [WorkoutSetModel]
    @ViewBuilder let row: (WorkoutSetModel) -> Row

    @State private var isExpanded = false

    var body: some View {
        if !sets.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(sets) { set in
                    row(set)
                }
            } label: {
                Label {
                    Text("\(sets.count) warm-ups")
                } icon: {
                    Image(systemName: Symbol.success)
                        .foregroundStyle(.success)
                }
                .font(.rowDetail)
                .frame(minHeight: ControlSize.row)
                .padding(.leading, Spacing.l)
            }
        }
    }
}
