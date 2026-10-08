//
//  SetStopwatch.swift
//  Compound
//
//  A timed set's time field with a start/stop button beside it (a plank, a dead hang). While it
//  runs, the live clock takes the field's place; a tap stops it and writes the seconds held into
//  the set. It never logs the set. The rule is `ActiveWorkout.Stopwatch`; this only draws it.
//

import SwiftUI

struct SetStopwatch<Field: View>: View {

    @Binding var set: WorkoutSetModel
    /// What the same set was held for last time. While running, a bar fills towards it.
    let targetSeconds: Int?
    /// The time field, shown while the stopwatch is stopped.
    @ViewBuilder let field: Field

    @State private var stopwatch = ActiveWorkout.Stopwatch()

    var body: some View {
        HStack(spacing: Spacing.xs) {
            button
            if !stopwatch.isRunning {
                field
            }
        }
        .reducedMotionAnimation(.quick, value: stopwatch.isRunning)
    }

    private var button: some View {
        Button(action: toggle) {
            Group {
                if let startedAt = stopwatch.startedAt {
                    VStack(spacing: Spacing.xxs) {
                        Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                            .font(.body.monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let target = stopwatch.targetInterval {
                            ProgressView(timerInterval: target, countsDown: false) {
                                EmptyView()
                            } currentValueLabel: {
                                EmptyView()
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.xs)
                } else {
                    Image(systemName: Symbol.start)
                        .font(.rowDetail)
                }
            }
            .foregroundStyle(stopwatch.isRunning ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.tint))
            .frame(minWidth: ControlSize.row, maxWidth: stopwatch.isRunning ? .infinity : ControlSize.row, minHeight: ControlSize.row)
            .background(
                stopwatch.isRunning ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.secondary),
                in: .rect(cornerRadius: Radius.s, style: .continuous)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(stopwatch.isRunning ? Text("Stop timer") : Text("Start timer"))
        .accessibilityValue(stopwatch.startedAt.map { Text("\(Text(timerInterval: $0...Date.distantFuture, countsDown: false)) elapsed") } ?? Text(verbatim: ""))
        .accessibilityHint(stopwatch.isRunning ? Text("Writes the time held into this set") : Text(verbatim: ""))
    }

    private func toggle() {
        if stopwatch.isRunning {
            guard let seconds = stopwatch.stop(at: .now) else { return }
            set.durationSec = seconds
            AccessibilityNotification.Announcement(Format.duration(TimeInterval(seconds))).post()
        } else {
            stopwatch.targetSeconds = targetSeconds
            stopwatch.start(at: .now)
        }
    }
}

#Preview {
    @Previewable @State var set: WorkoutSetModel = .mock
    SetStopwatch(set: $set, targetSeconds: 45) {
        Text(set.durationSec.map { Format.duration(TimeInterval($0)) } ?? Format.placeholder)
    }
    .frame(width: 90)
}
