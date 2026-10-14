//
//  SetKeyboardView.swift
//  Compound
//
//  The weight, reps, distance and duration keyboards. Shown as the input view of the row's fields, so it docks at
//  the bottom like the system keyboard, pushes the list up, and leaves hardware typing working.
//

import SwiftUI

struct SetKeyboardView: View {

    @Bindable var presenter: SetKeyboardPresenter
    /// Keys grow with Dynamic Type up to the keyboard's cap, so a larger label never clips.
    @ScaledMetric(relativeTo: .title2) private var keyHeight: CGFloat = SystemKeypad.keyHeight
    @ScaledMetric(relativeTo: .subheadline) private var plateStripHeight: CGFloat = 36
    /// The plates strip over the weight keypad, switched by the keypad's plates key and kept
    /// between workouts.
    @AppStorage("setKeyboard.showsPlates") private var showsPlates = true

    var body: some View {
        VStack(spacing: SystemKeypad.rowSpacing) {
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
        .padding(.horizontal, SystemKeypad.edgeInset)
        .padding(.top)
        .padding(.bottom, Spacing.xl + Spacing.l)
        .reducedMotionAnimation(.quick, value: presenter.activeField)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    // MARK: - Weight

    @ViewBuilder
    private var weightAccessories: some View {
        // A weight the bar cannot carry keeps the strip up, as it holds the nearest that can.
        // The step is not shown: − and + say it by what they do.
        if presenter.showsLoadingBar, showsPlates || presenter.plateLoading == nil {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                loadingBar
                if let loading = presenter.plateLoading {
                    Text(loading.equation)
                        .font(.rowDetail.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, Spacing.s)
                }
            }
        }
        if !presenter.context.step.bands.isEmpty {
            bandRow
        }
        if let stackSummary = presenter.stackSummary {
            Text(stackSummary)
                .font(.rowDetail.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: plateStripHeight)
        }
    }

    /// The gym's bands for this exercise, any number on at once, light to heavy. Beside the
    /// stepper, so a bar with bands takes both.
    private var bandRow: some View {
        chipStrip {
            rowHeading("Bands")
            ForEach(presenter.context.step.bands, id: \.self) { band in
                let isSelected = presenter.selectedBands.contains(band)
                Button {
                    presenter.toggleBand(band)
                    announceValue()
                } label: {
                    keyChip(band, isSelected: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(band)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    /// The bar and plates for the weight being typed, over the keypad on any plate-loaded
    /// exercise, unless the keypad's plates key has put it away. Tapping it opens the plate
    /// calculator, where the bar and the plates are chosen.
    private var loadingBar: some View {
        let unit = presenter.context.unit.abbreviation
        return HStack(spacing: Spacing.s) {
            Group {
                if let loading = presenter.plateLoading {
                    Button {
                        presenter.openPlateCalculator?()
                    } label: {
                        PlateLoadingView(loading: loading, plates: presenter.context.step.plates, showsEquation: false)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the plate calculator")
                } else if case let .notLoadable(below, above)? = presenter.plateLoad {
                    Label("Not loadable", systemImage: Symbol.warning)
                        .font(.rowDetail)
                        .foregroundStyle(.danger)
                    ForEach([below, above].compactMap { $0 }, id: \.self) { value in
                        Button("\(presenter.shownLoad(value)) \(unit)") {
                            presenter.applyWeight(displayValue: value)
                            announceValue()
                        }
                        .buttonStyle(.bordered)
                        .font(.rowDetail.monospacedDigit())
                        .accessibilityLabel("Use \(presenter.shownLoad(value)) \(unit)")
                    }
                }
            }
            Spacer(minLength: 0)
        }
        // A band on the keyboard itself, one line each for the plates and their sum, so it costs
        // a key's height and no more.
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, Spacing.s)
        .frame(minHeight: keyHeight)
    }

    // MARK: - Reps

    @ViewBuilder
    private var repsAccessories: some View {
        chipRow(presenter.repsChips) { presenter.applyReps(Int($0)) }
        if presenter.showsEffortChips {
            effortRow
        }
    }

    private var effortRow: some View {
        chipStrip {
            rowHeading("RIR")
                .accessibilityLabel("Reps in reserve")
            ForEach(EffortScale.rirChoices, id: \.self) { rir in
                let isSelected = presenter.selectedRIR == rir
                let text = EffortScale.rirText(rir)
                Button {
                    presenter.toggleRIR(rir)
                    if presenter.selectedRIR != nil {
                        AccessibilityNotification.Announcement(String(localized: "\(text) reps in reserve")).post()
                    }
                } label: {
                    keyChip(text, isSelected: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "\(text) reps in reserve"))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    // MARK: - Shared

    @ViewBuilder
    private func chipRow(_ chips: [SetKeyboardChip], apply: @escaping (Double) -> Void) -> some View {
        if !chips.isEmpty {
            chipStrip {
                ForEach(chips) { chip in
                    Button {
                        apply(chip.value)
                        announceValue()
                    } label: {
                        keyChip(chip.title)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// A row of chips over the keypad that scrolls sideways when it outgrows the width.
    private func chipStrip(@ViewBuilder _ content: () -> some View) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: SystemKeypad.keySpacing, content: content)
        }
        .scrollIndicators(.hidden)
    }

    /// A chip row's name, before its chips.
    private func rowHeading(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.label)
            .fontWeight(.bold)
            .foregroundStyle(.secondary)
    }

    /// Digits on the left, sized and spaced as the system number pad. The right-hand column, top
    /// to bottom: hide the keypad; show or hide the plates strip on a bar or plate-loaded machine
    /// (or ± on an assisted exercise); − and + on a weight; and Next → to the row's next field, or
    /// ✓ on its last, which logs the set. There is no Prev: an earlier field is a tap away.
    private var keypad: some View {
        Grid(horizontalSpacing: SystemKeypad.keySpacing, verticalSpacing: SystemKeypad.rowSpacing) {
            GridRow {
                digit("1"); digit("2"); digit("3")
                keyButton(.image(Symbol.hideKeyboard), label: String(localized: "Hide Keyboard")) { presenter.close() }
                    .frame(width: Self.sideColumnWidth)
            }
            GridRow {
                digit("4"); digit("5"); digit("6")
                Group {
                    if presenter.showsLoadingBar {
                        keyButton(.image(Symbol.plateCalculator), label: String(localized: "Show Plates")) {
                            withReducedMotionAnimation(.quick) { showsPlates.toggle() }
                        }
                        .accessibilityAddTraits(showsPlates ? .isSelected : [])
                    } else if presenter.showsSignKey {
                        keyButton(.text("±"), label: String(localized: "Change sign"), isKey: true) { presenter.toggleSign() }
                            .accessibilityHint("A negative weight is assistance")
                    } else {
                        blankKey
                    }
                }
                .frame(width: Self.sideColumnWidth)
            }
            GridRow {
                digit("7"); digit("8"); digit("9")
                Group {
                    if presenter.activeField == .weight {
                        HStack(spacing: SystemKeypad.keySpacing) {
                            keyButton(.image(Symbol.decrease), label: String(localized: "Decrease weight")) { presenter.stepDown() }
                            keyButton(.image(Symbol.add), label: String(localized: "Increase weight")) { presenter.stepUp() }
                        }
                    } else {
                        blankKey
                    }
                }
                .frame(width: Self.sideColumnWidth)
            }
            GridRow {
                if presenter.activeField?.takesDecimals == true {
                    keyButton(.text(presenter.decimalSeparator), label: String(localized: "Decimal point"), isKey: true, isPlain: true) { presenter.type(".") }
                } else {
                    blankKey
                }
                digit("0")
                keyButton(.image(Symbol.deleteBackward), label: String(localized: "Delete"), isKey: true, isPlain: true) { presenter.backspace() }
                Group {
                    if let next = presenter.nextField {
                        keyButton(.image(Symbol.nextField), label: String(localized: "Next, \(Self.name(of: next))"), prominent: true) { presenter.next() }
                    } else if presenter.isEditingLoggedSet {
                        keyButton(.image(Symbol.selected), label: String(localized: "Done"), prominent: true) { presenter.done() }
                            .accessibilityHint("Closes the keypad")
                    } else {
                        keyButton(.image(Symbol.selected), label: String(localized: "Log Set"), prominent: true) { presenter.done() }
                    }
                }
                .frame(width: Self.sideColumnWidth)
            }
        }
    }

    /// A chip over the keypad, drawn as a key: white like a digit, the accent when chosen, and a
    /// full 44 pt tall so it needs no padded hit area.
    private func keyChip(_ title: String, isSelected: Bool = false) -> some View {
        Text(title)
            .font(.rowDetail.weight(isSelected ? .semibold : .regular).monospacedDigit())
            .lineLimit(1)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: ControlSize.row)
            .foregroundStyle(isSelected ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.primary))
            .background(
                isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.surface),
                in: .rect(cornerRadius: SystemKeypad.keyRadius, style: .continuous)
            )
            .contentShape(.rect)
    }

    /// Wide enough for − and + side by side, each a 44 pt target.
    private static let sideColumnWidth = ControlSize.row * 2 + SystemKeypad.keySpacing

    /// The system number pad's metrics on iPhone (iOS 26), measured side by side with the phone
    /// pad on 13 Oct 2026 so the keypad feels like the keyboard it replaces. Measured rather than
    /// chosen, hence not design-system tokens.
    private enum SystemKeypad {
        static let keyHeight: CGFloat = 48
        static let keyRadius: CGFloat = Radius.m
        static let keySpacing: CGFloat = 6
        static let rowSpacing: CGFloat = 7
        static let edgeInset: CGFloat = Spacing.xs
    }

    private var blankKey: some View {
        Color.clear.frame(height: 1).accessibilityHidden(true)
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
        keyButton(.text(String(key)), label: String(key), isKey: true) { presenter.type(key) }
    }

    /// The field's new value, read out after a key, a step or a chip. The field is set from the
    /// presenter rather than typed into, so UIKit's own echo never speaks it.
    private func announceValue() {
        guard let value = presenter.spokenValue else { return }
        AccessibilityNotification.Announcement(value).post()
    }

    /// What a key shows: a digit or symbol typed as text, or an SF Symbol.
    private enum KeyFace {
        case text(String)
        case image(String)
    }

    /// Every key clicks as the system keyboard's do, following the user's Keyboard Clicks
    /// setting. The input view adopts `UIInputViewAudioFeedback`, which is what lets it sound.
    /// `isKey` marks a typing key: VoiceOver's touch typing then types it on lift. The new value is
    /// read back after a typing key or any symbol key.
    /// `isPlain` draws no key behind the label, as the system pad's decimal point and delete.
    private func keyButton(
        _ face: KeyFace,
        label: String,
        prominent: Bool = false,
        isKey: Bool = false,
        isPlain: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let announces: Bool = if case .image = face { true } else { isKey }
        return Button {
            UIDevice.current.playInputClick()
            action()
            if announces { announceValue() }
        } label: {
            Group {
                switch face {
                case .text(let title): Text(title)
                case .image(let name): Image(systemName: name)
                }
            }
            .font(.title2.weight(prominent ? .semibold : .regular))
            .frame(maxWidth: .infinity, minHeight: keyHeight)
            .foregroundStyle(prominent ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.primary))
            .background(
                prominent ? AnyShapeStyle(.tint) : isPlain ? AnyShapeStyle(.clear) : AnyShapeStyle(Color.surface),
                in: .rect(cornerRadius: SystemKeypad.keyRadius, style: .continuous)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isKey ? .isKeyboardKey : [])
    }
}

#Preview {
    let presenter = SetKeyboardPresenter()
    presenter.open(.weight, set: .constant(.mock), context: SetKeyboardContext())
    // The canvas never shows an input view, so this stands in for the system keyboard's glass
    // panel that `SetKeyboardInputHost` sits on in the app.
    return List {
        ForEach(1...12, id: \.self) { Text("Set \($0)") }
    }
    .overlay(alignment: .bottom) {
        SetKeyboardView(presenter: presenter)
            .glassEffect(.regular, in: .rect(cornerRadius: Radius.xl, style: .continuous))
            .ignoresSafeArea(edges: .bottom)
    }
}
