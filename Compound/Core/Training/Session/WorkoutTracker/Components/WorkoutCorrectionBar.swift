//
//  WorkoutCorrectionBar.swift
//  Compound
//
//  The set just logged, over the log button while its rest runs: a rep off or on, reps in reserve
//  and Undo. Off the card, so the set table stays sets only. Shake and ⌘Z still undo after the
//  rest (`WorkoutTrackerPresenter+Correction`).
//

import SwiftUI

struct WorkoutCorrectionBar: View {

    /// The set just logged, while its rest runs; `nil` hides the bar.
    let correction: SetCorrection?
    let onAction: @MainActor (SetCorrectionAction) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Side by side, or one under the other at accessibility sizes.
    private var lineLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(spacing: Spacing.m))
    }

    var body: some View {
        Group {
            if let correction {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    summaryLine(correction)
                    if correction.showsRIR {
                        rirLine(correction)
                    }
                }
                .padding(.horizontal, Spacing.s)
                // One VoiceOver container, read as "Set 2 logged, 100 kilograms, 8 reps", holding
                // its buttons.
                .accessibilityElement(children: .contain)
                .accessibilityLabel(correction.spokenLabel)
                .padding(.vertical, Spacing.xs)
                .cardSurface()
                .padding(.horizontal, Spacing.m)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .reducedMotionAnimation(.standard, value: correction)
    }

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
                    repsButton(systemImage: Symbol.decrease, label: String(localized: "Remove a rep"), delta: -1)
                        .disabled(!correction.canRemoveRep)
                    repsButton(systemImage: Symbol.add, label: String(localized: "Add a rep"), delta: 1)
                }
                Button("Undo") {
                    onAction(.undo)
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
            onAction(.reps(delta: delta))
        } label: {
            Image(systemName: systemImage)
                .font(.label.weight(.semibold))
                .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
                .background(.fill.secondary, in: .rect(cornerRadius: Radius.s, style: .continuous))
                .contentShape(.rect)
        }
        .accessibilityLabel(label)
    }

    /// "Reps in reserve  0 1 2 3 4 5 6+", one tap after the set and never in the way of the next.
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
        let text = EffortScale.rirText(chip)
        return Button {
            onAction(.rir(chip))
        } label: {
            Chip(text, isSelected: isSelected)
                .monospacedDigit()
                .chipTapTarget()
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(String(localized: "\(text) reps in reserve"))
    }
}

#Preview {
    WorkoutCorrectionBar(
        correction: SetCorrection(
            setId: "s2", title: "Set 2 · 100 kg × 8", spokenLabel: "Set 2 logged, 100 kilograms, 8 reps",
            correctsReps: true, canRemoveRep: true, showsRIR: true, selectedRIR: 2
        ),
        onAction: { _ in }
    )
}
