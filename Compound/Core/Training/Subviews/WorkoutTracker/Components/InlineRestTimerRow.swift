//
//  InlineRestTimerRow.swift
//  Compound
//
//  The rest line under the set just logged: the rest the set earns fills a bar beside its time,
//  then reads Ready. A rest that followed another exercise's set draws it at the top of the table.
//

import SwiftUI

struct InlineRestTimerRow: View {

    let timer: InlineRestTimer

    var body: some View {
        TimelineView(.explicit([Date()] + [timer.endsAt].compactMap { $0 })) { context in
            if let end = timer.endsAt, context.date < end {
                running(now: context.date, end: end)
            } else {
                readyLabel
            }
        }
        .padding(.horizontal, Spacing.s)
    }

    /// The bar filling against the rest this set earns, then "Rest: 1:27/1:30".
    private func running(now: Date, end: Date) -> some View {
        ProgressView(timerInterval: timer.startedAt...end, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            Text("Rest: \(Text(timerInterval: now...end))/\(Format.duration(end.timeIntervalSince(timer.startedAt)))")
        }
        .progressViewStyle(.restLine)
        .padding(.vertical, Spacing.xs)
    }
    
    private var readyLabel: some View {
        Label {
            Text("Ready")
        } icon: {
            Image(systemName: Symbol.success)
                .foregroundStyle(.success)
        }
        .font(.label.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.xs)
        .accessibilityLabel("Rest over, ready for the next set")
    }

}

#Preview {
    List {
        InlineRestTimerRow(
            timer: InlineRestTimer(anchor: .below(setId: "s2"), startedAt: .now.addingTimeInterval(-40), endsAt: .now.addingTimeInterval(80))
        )
        InlineRestTimerRow(timer: InlineRestTimer(anchor: .top, startedAt: .now, endsAt: nil))
    }
}
