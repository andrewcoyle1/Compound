//
//  SetTrackerRowView+SetType.swift
//  Compound
//
//  The set's kind on the row: its chip, its spoken name, an AMRAP target's placeholder and the
//  set-type menu.
//

import SwiftUI

extension SetTrackerRowView {

    /// The set's circle, with its kind's chip under it: "Failure", or "Drop", "Mini", "Partials",
    /// "Stretch" or "Hold" on a sub-row.
    /// Under rather than beside, so the columns keep the headers' widths.
    func setBadge(set: Binding<WorkoutSetModel>) -> some View {
        VStack(spacing: Spacing.xxs) {
            setNumber(set: set)
            kindChip(for: set.wrappedValue)
        }
    }

    /// The chip's text in the primary colour on its tint, as the circle's is: orange on its own
    /// 15 % fill is about 2:1 in light mode (S4). Hidden from VoiceOver, which hears the kind in
    /// the row's name.
    @ViewBuilder
    private func kindChip(for set: WorkoutSetModel) -> some View {
        if let chip = Self.chip(for: set) {
            Text(chip.text)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .fixedSize()
                .chipStyle(tint: chip.tint, filled: false)
                .accessibilityHidden(true)
        }
    }

    private static func chip(for set: WorkoutSetModel) -> (text: String, tint: Color)? {
        switch (set.subSetKind, set.kind) {
        case (.drop, _): (String(localized: "Drop"), .warmup)
        case let (.mini, kind): (kind.pieceName ?? String(localized: "Mini"), .warmup)
        case (nil, .amrap) where !set.isWarmup: (set.targetReps.map { String(localized: "Failure \($0)+") } ?? String(localized: "Failure"), .secondary)
        default: nil
        }
    }

    /// "AMRAP 8+" for an AMRAP set the plan gave a target, else the kind's name.
    static func kindName(of set: WorkoutSetModel) -> String {
        guard set.kind == .amrap, let target = set.targetReps else { return set.kind.displayName }
        return String(localized: "Failure \(target)+")
    }

    /// An AMRAP set's reps, while they are open, hint at the plan's target, greyed as any
    /// placeholder is: "8+".
    static func targetPlaceholder(for field: SetKeyboardField, set: WorkoutSetModel) -> String? {
        guard field == .reps, set.kind == .amrap, !set.isSubSet, !set.isWarmup, set.reps == nil,
              let target = set.targetReps else { return nil }
        return "\(target)+"
    }

    /// The types, the set's own ticked, then another drop or mini-set where the set takes one.
    @ViewBuilder
    func setTypeItems(set: Binding<WorkoutSetModel>) -> some View {
        Picker("Set Type", selection: Binding(
            get: { set.wrappedValue.typeChoice },
            set: { presenter.onSetTypeSelected($0, setId: set.wrappedValue.id, setName: rowName, exercise: delegate.exercise) }
        )) {
            ForEach(ActiveWorkout.setTypeOptions(for: set.wrappedValue), id: \.self) { choice in
                Text(choice.displayName).tag(choice)
            }
        }
        .pickerStyle(.inline)
        if ActiveWorkout.offersDrop(set.wrappedValue) {
            Button {
                presenter.addSubSet(.drop, to: set.wrappedValue.id, exercise: delegate.exercise)
            } label: {
                Label("Add Another Drop", systemImage: Symbol.add)
            }
            .accessibilityLabel(String(localized: "Add another drop to \(rowName)"))
        }
        if ActiveWorkout.offersMiniSet(set.wrappedValue) {
            Button {
                presenter.addSubSet(.mini, to: set.wrappedValue.id, exercise: delegate.exercise)
            } label: {
                Label("Add Another Mini-Set", systemImage: Symbol.add)
            }
            .accessibilityLabel(String(localized: "Add another mini-set to \(rowName)"))
        }
    }
}
