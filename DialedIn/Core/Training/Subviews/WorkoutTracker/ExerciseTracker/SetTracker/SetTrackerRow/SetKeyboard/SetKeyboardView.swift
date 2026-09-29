//
//  SetKeyboardView.swift
//  DialedIn
//
//  The weight and reps keyboards. Shown as the input view of the row's fields, so it docks at
//  the bottom like the system keyboard, pushes the list up, and leaves hardware typing working.
//

import SwiftUI

struct SetKeyboardView: View {

    @Bindable var presenter: SetKeyboardPresenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            if presenter.activeField == .reps {
                repsAccessories
            } else {
                weightAccessories
            }
            keypad
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, ignoresSafeAreaEdges: .bottom)
        .animation(reduceMotion ? nil : .snappy, value: presenter.activeField)
        .animation(reduceMotion ? nil : .snappy, value: presenter.showsPlates)
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
        return HStack(spacing: 8) {
            keyButton(systemImage: "minus", label: "Decrease weight") { presenter.stepDown() }
            HStack(spacing: 6) {
                Text(stepSummary)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let chip = presenter.context.step.chip {
                    Text(chip)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.tint.opacity(0.15), in: Capsule())
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
                        .frame(height: 40)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Shows the plates for each side of the bar")
            }
            keyButton(systemImage: "plus", label: "Increase weight") { presenter.stepUp() }
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
                Text(perSide.isEmpty ? String(localized: "Empty bar") : String(localized: "Per side: ") + perSide.map(WeightStepper.format).joined(separator: " + ") + " \(unit)")
            case let .notLoadable(below, above)?:
                HStack(spacing: 8) {
                    Text("Not loadable")
                        .foregroundStyle(.red)
                    ForEach([below, above].compactMap { $0 }, id: \.self) { value in
                        Button("\(WeightStepper.format(value)) \(unit)") {
                            presenter.applyWeight(displayValue: value)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Use \(WeightStepper.format(value)) \(unit)")
                    }
                }
            case nil:
                Text("Enter a weight to see the plates")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline.monospacedDigit())
        .frame(maxWidth: .infinity, minHeight: 36)
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
            HStack(spacing: 6) {
                Text("RPE")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ForEach(EffortScale.rpeChoices, id: \.self) { rpe in
                    let isSelected = presenter.selectedRPE == rpe
                    Button(WeightStepper.format(rpe)) {
                        presenter.toggleRPE(rpe)
                    }
                    .font(.subheadline.monospacedDigit())
                    .buttonStyle(.bordered)
                    .tint(isSelected ? .accentColor : .secondary)
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
                HStack(spacing: 6) {
                    ForEach(chips) { chip in
                        Button(chip.title) { apply(chip.value) }
                            .font(.subheadline)
                            .buttonStyle(.bordered)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var keypad: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                digit("1"); digit("2"); digit("3")
                if presenter.activeField == .reps {
                    keyButton(title: String(localized: "Prev"), label: "Previous, weight") { presenter.previous() }
                        .disabled(!presenter.context.tracksWeight)
                } else {
                    keyButton(title: String(localized: "Next"), label: "Next, reps") { presenter.next() }
                }
            }
            GridRow {
                digit("4"); digit("5"); digit("6")
                Color.clear.frame(height: 1).accessibilityHidden(true)
            }
            GridRow {
                digit("7"); digit("8"); digit("9")
                keyButton(title: String(localized: "Done"), label: "Done", prominent: true) { presenter.done() }
            }
            GridRow {
                if presenter.activeField == .weight {
                    keyButton(title: ".", label: "Decimal point") { presenter.type(".") }
                } else {
                    Color.clear.frame(height: 1).accessibilityHidden(true)
                }
                digit("0")
                keyButton(systemImage: "delete.left", label: "Delete") { presenter.backspace() }
                Color.clear.frame(height: 1).accessibilityHidden(true)
            }
        }
    }

    private func digit(_ key: Character) -> some View {
        keyButton(title: String(key), label: String(key)) { presenter.type(key) }
    }

    private func keyButton(title: String, label: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(prominent ? .semibold : .regular))
                .frame(maxWidth: .infinity, minHeight: 46)
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .background(prominent ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.secondary), in: .rect(cornerRadius: 10))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func keyButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 46)
                .foregroundStyle(Color.primary)
                .background(.fill.secondary, in: .rect(cornerRadius: 10))
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
