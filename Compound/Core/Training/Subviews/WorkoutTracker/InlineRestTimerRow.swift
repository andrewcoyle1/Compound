//
//  InlineRestTimerRow.swift
//  Compound
//
//  The line of the set table under the set just logged: the correction row. It says what was
//  logged, takes a rep off or puts one on, records reps in reserve and undoes the log; under that,
//  the rest the set earns fills a bar beside its time, then reads Ready. A rest that followed
//  another exercise's set draws the rest line alone, at the top of the table.
//

import SwiftUI

/// What the correction row says about the set it follows. See `WorkoutTrackerPresenter+Correction`.
struct SetCorrection: Equatable {
    let setId: String
    /// "Set 2 · 100 kg × 8".
    let title: String
    /// "Set 2 logged, 100 kilograms, 8 reps".
    let spokenLabel: String
    /// The reps buttons, for a set counted in reps.
    let correctsReps: Bool
    /// False at one rep: a set is at least one.
    let canRemoveRep: Bool
    /// The reps-in-reserve chips, with `WorkoutSettings.rirTracking` on.
    let showsRIR: Bool
    let selectedRIR: Int?
}

/// What a tap on the correction row asks for.
enum SetCorrectionAction: Equatable {
    case reps(delta: Int)
    case rir(Int)
    case undo
}

struct InlineRestTimerRow: View {

    let timer: InlineRestTimer?
    var correction: SetCorrection?
    var onCorrection: @MainActor (SetCorrectionAction) -> Void = { _ in }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    /// Side by side, or one under the other at accessibility sizes.
    private var lineLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(spacing: Spacing.m))
    }

    var body: some View {
        container {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                if let correction {
                    summaryLine(correction)
                    if correction.showsRIR {
                        rirLine(correction)
                    }
                }
                if let timer {
                    restLine(timer)
                }
            }
            .padding(.horizontal, Spacing.s)
        }
    }

    /// One VoiceOver container per row, read as "Set 2 logged, 100 kilograms, 8 reps", holding
    /// its buttons. The rest line alone keeps its own reading.
    @ViewBuilder
    private func container(@ViewBuilder _ content: () -> some View) -> some View {
        if let correction {
            content()
                .accessibilityElement(children: .contain)
                .accessibilityLabel(correction.spokenLabel)
        } else {
            content()
        }
    }

    // MARK: - Correction

    /// "✓ Set 2 · 100 kg × 8   [−] [+]   Undo".
    private func summaryLine(_ correction: SetCorrection) -> some View {
        lineLayout {
            // The green on the tick only: green caption text is about 2.2:1 in light mode (S4).
            Label {
                Text(correction.title)
            } icon: {
                Image(systemName: Symbol.success)
                    .foregroundStyle(.success)
            }
                .font(.label.weight(.semibold))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
                // The container's label says it, with the units in words.
                .accessibilityHidden(true)
            HStack(spacing: Spacing.s) {
                if correction.correctsReps {
                    // Not in `Symbol`, which this package does not own; the keypad's stepper uses
                    // the same symbol.
                    repsButton(systemImage: "minus", label: String(localized: "Remove a rep"), delta: -1)
                        .disabled(!correction.canRemoveRep)
                    repsButton(systemImage: Symbol.add, label: String(localized: "Add a rep"), delta: 1)
                }
                Button("Undo") {
                    onCorrection(.undo)
                }
                .font(.label.weight(.semibold))
                .frame(minHeight: ControlSize.row)
                .contentShape(.rect)
                .accessibilityIdentifier("WorkoutTracker.correctionUndo")
            }
            // Inside a list row: each button takes its own tap rather than the row's.
            .buttonStyle(.borderless)
        }
    }

    private func repsButton(systemImage: String, label: String, delta: Int) -> some View {
        Button {
            onCorrection(.reps(delta: delta))
        } label: {
            Image(systemName: systemImage)
                .font(.label.weight(.semibold))
                .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
                .background(.fill.secondary, in: .rect(cornerRadius: Radius.s, style: .continuous))
                .contentShape(.rect)
        }
        .accessibilityLabel(label)
    }

    /// "Reps in reserve  0 1 2 3 4+", one tap after the set and never in the way of the next.
    private func rirLine(_ correction: SetCorrection) -> some View {
        lineLayout {
            Text("Reps in reserve")
                .font(.label)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.s) {
                    ForEach(ActiveWorkout.rirChips, id: \.self) { chip in
                        rirChip(chip, isSelected: correction.selectedRIR == chip)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func rirChip(_ chip: Int, isSelected: Bool) -> some View {
        let isLast = chip == ActiveWorkout.rirChips.last
        return Button {
            onCorrection(.rir(chip))
        } label: {
            Group {
                if isLast {
                    Chip("4+", isSelected: isSelected)
                } else {
                    Chip("\(chip)", isSelected: isSelected)
                }
            }
            .monospacedDigit()
            .chipTapTarget()
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(isLast ? String(localized: "4 or more in reserve") : String(localized: "\(chip) in reserve"))
    }

    // MARK: - Rest

    @ViewBuilder
    private func restLine(_ timer: InlineRestTimer) -> some View {
        // Drawn now and again at the moment the rest runs out, so it turns to Ready with no
        // ticking clock. The first entry must be now: an explicit schedule draws its first frame
        // at its first date, which on its own would be the end of the rest.
        TimelineView(.explicit([Date()] + [timer.endsAt].compactMap { $0 })) { context in
            if let end = timer.endsAt, context.date < end {
                running(timer, now: context.date, end: end)
            } else {
                // As the correction line: the colour on the tick, the word in the label colour.
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
    }

    /// The bar filling against the rest this set earns, then "Rest: 1:27/1:30".
    private func running(_ timer: InlineRestTimer, now: Date, end: Date) -> some View {
        lineLayout {
            if let start = timer.startedAt, start < end {
                ProgressView(timerInterval: start...end, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                Text("Rest: \(Text(timerInterval: now...end))/\(Format.duration(end.timeIntervalSince(start)))")
                    .font(.label.weight(.semibold))
                    .layoutPriority(1)
            } else {
                Text("Rest: \(Text(timerInterval: now...end))")
                    .font(.label.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .monospacedDigit()
        // Increase Contrast asks for more than secondary text gives.
        .foregroundStyle(colorSchemeContrast == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let correction = SetCorrection(
        setId: "s2", title: "Set 2 · 100 kg × 8", spokenLabel: "Set 2 logged, 100 kilograms, 8 reps",
        correctsReps: true, canRemoveRep: true, showsRIR: true, selectedRIR: 2
    )
    List {
        InlineRestTimerRow(
            timer: InlineRestTimer(anchor: .below(setId: "s2"), startedAt: .now.addingTimeInterval(-40), endsAt: .now.addingTimeInterval(80)),
            correction: correction
        )
        InlineRestTimerRow(timer: nil, correction: correction)
        InlineRestTimerRow(timer: InlineRestTimer(anchor: .top, startedAt: .now, endsAt: nil))
    }
}
