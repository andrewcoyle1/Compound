//
//  MethodInfoButton.swift
//  Compound
//
//  The ⓘ beside a calculated figure. Tapping it opens `MethodInfoSheet`: what the figure is, how it
//  is worked out, its limits, and the sources, each linking to its DOI.
//
//  The sheet is view state, not navigation, so the button presents it itself and any screen can
//  place one without routing: in a section header, beside a stat's title, or in a toolbar.
//

import SwiftUI

struct MethodInfoButton: View {
    let info: MethodInfo

    @State private var isPresented = false

    init(_ info: MethodInfo) {
        self.info = info
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: Symbol.info)
                .iconSize(.small)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.tint)
        .accessibilityLabel(Text("How \(Text(info.title)) is calculated"))
        .accessibilityHint(Text("Shows the method and its sources"))
        .sheet(isPresented: $isPresented) {
            MethodInfoSheet(info: info)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

/// A section header with a method button at its trailing edge.
struct MethodInfoHeader: View {
    let title: LocalizedStringResource
    let info: MethodInfo

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(title)
            Spacer(minLength: Spacing.xs)
            MethodInfoButton(info)
                .textCase(nil)
        }
    }
}

struct MethodInfoSheet: View {
    let info: MethodInfo

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(info.summary)
                        .font(.rowDetail)
                }
                if let formula = info.formula {
                    Section("Formula") {
                        Text(verbatim: formula)
                            .font(.rowDetail.monospaced())
                            .textSelection(.enabled)
                    }
                }
                if let limitations = info.limitations {
                    Section("Limitations") {
                        Text(limitations)
                            .font(.rowDetail)
                    }
                }
                if let ownChoices = info.ownChoices {
                    Section("Compound's own choices") {
                        Text(ownChoices)
                            .font(.rowDetail)
                    }
                }
                Section("Sources") {
                    ForEach(info.citations) { citation in
                        CitationRow(citation: citation)
                    }
                }
            }
            .navigationTitle(Text(info.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CitationRow: View {
    let citation: Citation

    var body: some View {
        if let link = citation.link {
            Link(destination: link) {
                content
            }
            .accessibilityHint(Text("Opens the source"))
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(verbatim: citation.reference)
                .font(.rowDetail)
                .foregroundStyle(.primary)
            if !citation.isPeerReviewed {
                Text("Not peer reviewed")
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
            if let linkText = citation.linkText {
                Text(verbatim: linkText)
                    .font(.label)
                    .foregroundStyle(.tint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    MethodInfoSheet(info: MethodInfo(
        id: "preview",
        title: "Resting energy",
        summary: "Estimated with the Mifflin-St Jeor equation.",
        formula: "RMR = 10·W + 6.25·H − 5·A + s",
        limitations: "About three in four people fall within 10% of a measured value.",
        citations: [.mifflin1990, .frankenfield2005]
    ))
}
