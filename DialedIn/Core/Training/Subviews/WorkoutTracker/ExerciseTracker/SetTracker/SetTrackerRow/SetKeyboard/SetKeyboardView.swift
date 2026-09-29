//
//  SetKeyboardView.swift
//  DialedIn
//
//  The weight, reps, distance and duration keyboards. Shown as the input view of the row's fields, so it docks at
//  the bottom like the system keyboard, pushes the list up, and leaves hardware typing working.
//

import SwiftUI

struct SetKeyboardView: View {

    @Bindable var presenter: SetKeyboardPresenter
    /// Keys grow with Dynamic Type up to the keyboard's cap, so a larger label never clips.
    @ScaledMetric(relativeTo: .title3) private var keyHeight: CGFloat = 46
    @ScaledMetric(relativeTo: .subheadline) private var plateStripHeight: CGFloat = 36

    var body: some View {
        VStack(spacing: Spacing.s) {
            switch presenter.activeField {
            case .reps:
                repsAccessories
            case .weight, nil:
                weightAccessories
            case .distance, .duration:
                // Only the keypad: there is no equipment step or last-set chip for these.
                EmptyView()
            }
            keypad
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.m)
        .background(.regularMaterial, ignoresSafeAreaEdges: .bottom)
        .reducedMotionAnimation(.quick, value: presenter.activeField)
        .reducedMotionAnimation(.quick, value: presenter.showsPlates)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    // MARK: - Weight

    @ViewBuilder
    private var weightAccessories: some View {
        chipRow(presenter.weightChips) { presenter.applyWeight(displayValue: $0) }
        stepperRow
        if presenter.showsPlates {
            plateStrip
        }
    }

    private var stepperRow: some View {
        let unit = presenter.context.unit.abbreviation
        return HStack(spacing: Spacing.s) {
            keyButton(systemImage: "minus", label: String(localized: "Decrease weight")) { presenter.stepDown() }
            HStack(spacing: Spacing.s) {
                Text(stepSummary)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let chip = presenter.context.step.chip {
                    Chip(chip)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Weight in \(unit). \(stepSummary). \(presenter.context.step.chip ?? "")")
            if presenter.context.step.isPlateLoaded {
                Button {
                    presenter.showsPlates.toggle()
                } label: {
                    Text("Plates")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.glass)
                .accessibilityHint("Shows the plates for each side of the bar")
            }
            keyButton(systemImage: Symbol.add, label: "Increase weight") { presenter.stepUp() }
        }
    }

    private var stepSummary: String {
        switch presenter.context.step.kind {
        case .increment(let step, _, _):
            return "± \(WeightStepper.format(step)) \(presenter.context.unit.abbreviation)"
        case .list:
            return String(localized: "Next available")
        case .bands:
            return String(localized: "Cycle bands")
        }
    }

    @ViewBuilder
    private var plateStrip: some View {
        let unit = presenter.context.unit.abbreviation
        Group {
            switch presenter.plateLoad {
            case .loadable(let perSide)?:
                Text(perSide.isEmpty ? String(localized: "Empty bar") : String(localized: "Per side: ") + perSide.map { WeightStepper.format($0) }.joined(separator: " + ") + " \(unit)")
            case let .notLoadable(below, above)?:
                HStack(spacing: Spacing.s) {
                    Label("Not loadable", systemImage: Symbol.warning)
                        .foregroundStyle(.danger)
                    ForEach([below, above].compactMap { $0 }, id: \.self) { value in
                        Button("\(WeightStepper.format(value)) \(unit)") {
                            presenter.applyWeight(displayValue: value)
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Use \(WeightStepper.format(value)) \(unit)")
                    }
                }
            case nil:
                Text("Enter a weight to see the plates")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline.monospacedDigit())
        .frame(maxWidth: .infinity, minHeight: plateStripHeight)
    }

    // MARK: - Reps

    @ViewBuilder
    private var repsAccessories: some View {
        chipRow(presenter.repsChips) { presenter.applyReps(Int($0)) }
        if presenter.context.showsEffort {
            effortRow
        }
    }

    private var effortRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.s) {
                Text("RPE")
                    .font(.label)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                ForEach(EffortScale.rpeChoices, id: \.self) { rpe in
                    let isSelected = presenter.selectedRPE == rpe
                    Button {
                        presenter.toggleRPE(rpe)
                    } label: {
                        Chip(WeightStepper.format(rpe), isSelected: isSelected)
                            .monospacedDigit()
                            .chipTapTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("RPE \(WeightStepper.format(rpe)), \(WeightStepper.format(EffortScale.rir(fromRPE: rpe))) reps in reserve")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Shared

    @ViewBuilder
    private func chipRow(_ chips: [SetKeyboardChip], apply: @escaping (Double) -> Void) -> some View {
        if !chips.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.s) {
                    ForEach(chips) { chip in
                        Button {
                            apply(chip.value)
                        } label: {
                            Chip(chip.title)
                                .chipTapTarget()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var keypad: some View {
        Grid(horizontalSpacing: Spacing.s, verticalSpacing: Spacing.s) {
            GridRow {
                digit("1"); digit("2"); digit("3")
                if let next = presenter.nextField {
                    keyButton(title: String(localized: "Next"), label: String(localized: "Next, \(Self.name(of: next))")) { presenter.next() }
                } else {
                    let previous = presenter.previousField
                    keyButton(
                        title: String(localized: "Prev"),
                        label: previous.map { String(localized: "Previous, \(Self.name(of: $0))") } ?? String(localized: "Previous")
                    ) { presenter.previous() }
                    .disabled(previous == nil)
                }
            }
            GridRow {
                digit("4"); digit("5"); digit("6")
                Color.clear.frame(height: 1).accessibilityHidden(true)
            }
            GridRow {
                digit("7"); digit("8"); digit("9")
                keyButton(title: String(localized: "Done"), label: String(localized: "Done"), prominent: true) { presenter.done() }
            }
            GridRow {
                if presenter.activeField?.takesDecimals == true {
                    keyButton(title: presenter.decimalSeparator, label: String(localized: "Decimal point")) { presenter.type(".") }
                } else {
                    Color.clear.frame(height: 1).accessibilityHidden(true)
                }
                digit("0")
                keyButton(systemImage: "delete.left", label: String(localized: "Delete")) { presenter.backspace() }
                Color.clear.frame(height: 1).accessibilityHidden(true)
            }
        }
    }

    private static func name(of field: SetKeyboardField) -> String {
        switch field {
        case .weight: return String(localized: "weight")
        case .reps: return String(localized: "reps")
        case .distance: return String(localized: "distance")
        case .duration: return String(localized: "time")
        }
    }

    private func digit(_ key: Character) -> some View {
        keyButton(title: String(key), label: String(key)) { presenter.type(key) }
    }

    /// Every key clicks as the system keyboard's do, following the user's Keyboard Clicks
    /// setting. The input view adopts `UIInputViewAudioFeedback`, which is what lets it sound.
    private func keyButton(title: String, label: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            UIDevice.current.playInputClick()
            action()
        } label: {
            Text(title)
                .font(.title3.weight(prominent ? .semibold : .regular))
                .frame(maxWidth: .infinity, minHeight: keyHeight)
                .foregroundStyle(prominent ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.primary))
                .background(prominent ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.secondary), in: .rect(cornerRadius: Radius.s, style: .continuous))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func keyButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            UIDevice.current.playInputClick()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: keyHeight)
                .foregroundStyle(Color.primary)
                .background(.fill.secondary, in: .rect(cornerRadius: Radius.s, style: .continuous))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: systemImage == "delete.left" ? .infinity : 64)
        .accessibilityLabel(label)
    }
}

#Preview {
    @Previewable @State var set: WorkoutSetModel = .mock
    let presenter = SetKeyboardPresenter()
    presenter.open(.weight, set: $set, context: SetKeyboardContext(lastSetWeightKg: 60, previousSessionWeightKg: 57.5))
    return VStack {
        Spacer()
        SetKeyboardView(presenter: presenter)
    }
}
