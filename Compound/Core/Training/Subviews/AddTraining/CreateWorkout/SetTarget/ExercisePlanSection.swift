//
//  ExercisePlanSection.swift
//  Compound
//
//  The set-target editor's plan for a template exercise: warm-ups, rest, notes, link, weekly
//  variation and substitutions. Rows only; the presenter holds every rule.
//

import SwiftUI

struct ExercisePlanSection: View {

    @Bindable var presenter: SetTargetPresenter

    @FocusState private var isLinkFocused: Bool

    var body: some View {
        Section("Plan") {
            Picker("Warm-up sets", selection: $presenter.warmupSetCount) {
                ForEach(presenter.warmupSetChoices, id: \.self) { count in
                    Text(presenter.warmupSetTitle(count)).tag(count)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("SetTarget.warmupSets")

            Picker("Rest", selection: $presenter.restSeconds) {
                ForEach(presenter.restSecondsChoices, id: \.self) { seconds in
                    Text(presenter.restTitle(seconds)).tag(seconds)
                }
            }
            .pickerStyle(.menu)

            TextField("Notes", text: $presenter.notes, axis: .vertical)
                .lineLimit(2...6)

            linkRow

            ListRowButton(title: String(localized: "Varies by week"), subtitle: presenter.variationSummary) {
                presenter.onVariesByWeekPressed()
            }
            .accessibilityIdentifier("SetTarget.variesByWeek")
        }

        Section("Substitutions") {
            ForEach(presenter.substitutes) { exercise in
                ListRow(title: exercise.name, imageName: exercise.imageURL, initialsWhenMissing: true)
                    .rowActions {
                        Button(role: .destructive) {
                            presenter.onRemoveSubstitutionPressed(exercise)
                        } label: {
                            Label("Remove", systemImage: Symbol.delete)
                        }
                    }
            }
            Button {
                presenter.onAddSubstitutionPressed()
            } label: {
                Label("Add substitution", systemImage: Symbol.add)
            }
        }
    }

    /// Checked when the field is left, as the HIG asks of an address, rather than at every keystroke.
    private var linkRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TextField("Link", text: $presenter.linkText)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isLinkFocused)
                .onSubmit { presenter.onLinkSubmitted() }
                .onChange(of: isLinkFocused) { _, isFocused in
                    if !isFocused { presenter.onLinkSubmitted() }
                }
            if presenter.showsLinkError {
                InlineMessage(.error, "Enter a web address starting with http:// or https://")
            }
        }
    }
}
