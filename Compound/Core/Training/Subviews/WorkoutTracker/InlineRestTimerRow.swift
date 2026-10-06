//
//  InlineRestTimerRow.swift
//  Compound
//
//  The rest timer as one line of the set table, under the set it follows: a bar filling against
//  the rest that set earns with the time beside it, then Ready. Skipping and extending are on the
//  log button.
//

import SwiftUI

struct InlineRestTimerRow: View {

    let timer: InlineRestTimer

    var body: some View {
        // Drawn now and again at the moment the rest runs out, so it turns to Ready with no
        // ticking clock. The first entry must be now: an explicit schedule draws its first frame
        // at its first date, which on its own would be the end of the rest.
        TimelineView(.explicit([Date()] + [timer.endsAt].compactMap { $0 })) { context in
            if let end = timer.endsAt, context.date < end {
                running(now: context.date, end: end)
            } else {
                Label("Ready", systemImage: Symbol.success)
                    .font(.label.weight(.semibold))
                    .foregroundStyle(.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Spacing.xs)
                    .accessibilityLabel("Rest over, ready for the next set")
            }
        }
        .padding(.horizontal, Spacing.s)
    }

    /// One line: the bar filling against the rest this set earns, then "Rest: 1:27/1:30".
    private func running(now: Date, end: Date) -> some View {
        HStack(spacing: Spacing.m) {
            if let start = timer.startedAt, start < end {
                ProgressView(timerInterval: start...end, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                Text("Rest: \(Text(timerInterval: now...end))/\(Format.duration(end.timeIntervalSince(start)))")
                    .font(.label.weight(.semibold))
                    .fixedSize()
            } else {
                Spacer()
                Text("Rest: \(Text(timerInterval: now...end))")
                    .font(.label.weight(.semibold))
            }
        }
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        InlineRestTimerRow(timer: InlineRestTimer(anchor: .top, startedAt: .now.addingTimeInterval(-40), endsAt: .now.addingTimeInterval(80)))
        InlineRestTimerRow(timer: InlineRestTimer(anchor: .top, startedAt: .now, endsAt: nil))
    }
}
