//
//  SectionHeaderView.swift
//  DialedIn
//
//  The list section header shared by every tab. It began life as `AnalyticsSectionHeader` and was
//  used only by the Analytics tab, so the Dashboard grew plain `Text` headers instead and its
//  sections had no way to offer a destination. One header, so a new section cannot pick a
//  different treatment.
//

import SwiftUI

/// A section title with an optional trailing action. Sections without a destination simply omit the
/// action and get the title alone.
struct SectionHeaderView: View {

    let title: String
    /// The trailing link's wording. "See All" suits a grid that is showing a subset; a feed that is
    /// already showing everything wants something else ("Find People").
    var actionTitle: String
    var onActionPressed: (() -> Void)?

    /// A literal title is looked up in the string catalog, so a call site cannot ship English by
    /// passing a bare string.
    init(title: LocalizedStringResource, actionTitle: LocalizedStringResource = "See All", onActionPressed: (() -> Void)? = nil) {
        self.init(title: String(localized: title), actionTitle: String(localized: actionTitle), onActionPressed: onActionPressed)
    }

    /// For a title that is already a runtime `String`, localized or user content.
    @_disfavoredOverload
    init(title: String, actionTitle: String = String(localized: "See All"), onActionPressed: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.onActionPressed = onActionPressed
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Text(title)

            if let onActionPressed {
                Spacer(minLength: Spacing.s)
                // A link, so it takes the accent (CONTRACT.md § Accent). The caption-sized label
                // is padded out to the 44 pt minimum hit area.
                Button(action: onActionPressed) {
                    // A 44 pt frame rather than `tapTarget()`'s overhang: as a list section header
                    // this sits in its own cell, which would clip a hit area reaching past it.
                    Text(actionTitle)
                        .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .font(.label)
                .foregroundStyle(.tint)
                .accessibilityLabel("\(actionTitle), \(title)")
            }
        }
    }
}

private struct SectionHeaderPreview: View {
    var body: some View {
        List {
            Section {
                Text("Row")
            } header: {
                SectionHeaderView(title: "With Action", onActionPressed: { })
            }

            Section {
                Text("Row")
            } header: {
                SectionHeaderView(title: "Title Only")
            }
        }
    }
}

#Preview("Section header, light") {
    SectionHeaderPreview().preferredColorScheme(.light)
}

#Preview("Section header, dark") {
    SectionHeaderPreview().preferredColorScheme(.dark)
}

#Preview("Section header, accessibility3") {
    SectionHeaderPreview().dynamicTypeSize(.accessibility3)
}
