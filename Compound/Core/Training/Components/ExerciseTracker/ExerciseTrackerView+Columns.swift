//
//  ExerciseTrackerView+Columns.swift
//  Compound
//
//  The column headings over the set rows: Set, the Last/Auto switch, a heading per input with
//  its unit menu, and Done.
//

import SwiftUI

extension ExerciseTrackerView {

    func columnHeaders(setLabel: String?) -> some View {
        let unitPreference = presenter.getUnitPreference(for: delegate.exercise.wrappedValue)
        return Group {
            if isStacked {
                // Over the stacked rows: the Prev/Auto switch for line one, the input headers over
                // the inputs of line two. The set and Done controls need no heading.
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if let setLabel {
                        Text(setLabel)
                    }
                    prevAutoHeader
                    inputHeaders(units: unitPreference)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(setLabel ?? String(localized: "Set"))
                        .frame(width: SetTrackerRowView.setColumnWidth, alignment: .center)
                    Spacer()
                    prevAutoHeader
                    Spacer()
                    inputHeaders(units: unitPreference)
                    Spacer()
                    Text("Done")
                        .frame(width: SetTrackerRowView.doneColumnWidth, alignment: .center)
                }
                // No line limit and no shrinking: Caption 2 is already the 11 pt floor, so a
                // heading too long for its column wraps instead.
                .multilineTextAlignment(.center)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    /// One header per input the rows show, at the rows' widths. The weight header stood over every
    /// exercise, so a run was headed with a kg menu and "Reps".
    @ViewBuilder
    private func inputHeaders(units: ExerciseUnitPreference) -> some View {
        HStack(spacing: Spacing.s) {
            switch delegate.exercise.wrappedValue.trackingMode {
            case .weightReps:
                weightUnitMenu(units.weightUnit)
                    .setColumn(width: SetTrackerRowView.fieldColumnWidth, stretches: isStacked)
                Text("Reps")
                    .setColumn(width: SetTrackerRowView.repsColumnWidth, stretches: isStacked)
            case .repsOnly:
                Text("Reps")
                    .setColumn(width: SetTrackerRowView.repsColumnWidth, stretches: isStacked)
            case .timeOnly:
                Text("Time")
                    .setColumn(width: SetTrackerRowView.timeColumnWidth, stretches: isStacked)
            case .distanceTime:
                distanceUnitMenu(units.distanceUnit)
                    .setColumn(width: SetTrackerRowView.fieldColumnWidth, stretches: isStacked)
                Text("Time")
                    .setColumn(width: SetTrackerRowView.fieldColumnWidth, stretches: isStacked)
            }
        }
    }
    
    private var prevAutoHeader: some View {
        Button {
            showAutoRanges.toggle()
        } label: {
            // A chip inside a real 44 pt frame, so the column stays narrow and the tap target full.
            // A one-word heading cannot wrap and must not shrink below 11 pt, so where the column
            // is too narrow for the symbol as well, the chip drops it.
            ViewThatFits(in: .horizontal) {
                prevAutoChip(showsSymbol: true).fixedSize()
                prevAutoChip(showsSymbol: false).fixedSize()
            }
            .frame(minHeight: ControlSize.row)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Switches between last session and smart progression")
        .frame(width: isStacked ? nil : SetTrackerRowView.previousColumnWidth, alignment: .center)
    }

    /// An `HStack` rather than a `Label`: in a list a label sets aside an icon column as wide as a
    /// row's, which left the word no room.
    private func prevAutoChip(showsSymbol: Bool) -> some View {
        HStack(spacing: Spacing.xxs) {
            if showsSymbol {
                Image(systemName: showAutoRanges ? Symbol.smartProgression : Symbol.history)
                    .accessibilityHidden(true)
            }
            if showAutoRanges {
                Text("Auto")
            } else {
                Text("Last")
            }
        }
        .lineLimit(1)
        .chipStyle(tint: .secondary, filled: false)
    }

    private func weightUnitMenu(_ selected: ExerciseWeightUnit) -> some View {
        let exercise = delegate.exercise
        return unitMenu(
            ExerciseWeightUnit.allCases, selected: selected, name: \.displayName,
            label: Text(presenter.weightColumnTitle(for: exercise.wrappedValue, unit: selected))
                .accessibilityLabel(presenter.weightColumnLabel(for: exercise.wrappedValue, unit: selected))
        ) { presenter.promptWeightUnitChange($0, for: exercise) }
    }

    private func distanceUnitMenu(_ selected: ExerciseDistanceUnit) -> some View {
        let exercise = delegate.exercise
        return unitMenu(
            ExerciseDistanceUnit.allCases, selected: selected, name: \.displayName,
            label: Text(selected.abbreviation.capitalized)
                .accessibilityLabel(String(localized: "Distance unit, \(selected.displayName)"))
        ) { presenter.promptDistanceUnitChange($0, for: exercise) }
    }

    /// A column heading that is also the unit's menu, the chosen unit ticked.
    private func unitMenu<Unit: Hashable>(
        _ units: [Unit],
        selected: Unit,
        name: @escaping (Unit) -> String,
        label: some View,
        onSelect: @escaping (Unit) -> Void
    ) -> some View {
        Menu {
            ForEach(units, id: \.self) { unit in
                Button {
                    onSelect(unit)
                } label: {
                    if unit == selected {
                        Label(name(unit), systemImage: Symbol.selected)
                    } else {
                        Text(name(unit))
                    }
                }
            }
        } label: {
            label
                .chipStyle(tint: .secondary, filled: false)
                .frame(minHeight: ControlSize.row)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
