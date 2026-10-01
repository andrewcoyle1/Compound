//
//  Dashboard.swift
//  Compound
//

import SwiftUI

/// A tab root's sections: a `List` at phone widths, and at iPad and Mac widths the same sections as
/// cards in two columns, so a wide window is not one long strip down the middle. Pass `Section`s
/// exactly as to a `List`; list-only modifiers inside them simply do nothing in the columns.
struct Dashboard<Content: View>: View {

    @ViewBuilder var content: Content

    /// The width the columns have to share. The frame is already inside the router's centring
    /// padding, so it is not reduced by the safe area again: doing so halved it on a wide Mac
    /// window and dropped the screen back to one column.
    @State private var width: CGFloat = 0

    var body: some View {
        Group {
            if width >= ContentWidth.twoColumns {
                ScrollView {
                    columns
                        .padding(.horizontal)
                        .padding(.bottom, Spacing.xl)
                }
                .background(Color.canvas)
            } else {
                List { content }
            }
        }
        .preferredReadableContentWidth(ContentWidth.dashboard)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    /// Sections alternate left and right, so reading order runs across then down.
    private var columns: some View {
        Group(sections: content) { sections in
            HStack(alignment: .top, spacing: Spacing.l) {
                ForEach(0..<2, id: \.self) { column in
                    VStack(spacing: Spacing.xl) {
                        ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                            if index % 2 == column {
                                card(section)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
    }

    private func card(_ section: SectionConfiguration) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if !section.header.isEmpty {
                section.header
                    .font(.sectionTitle)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            VStack(alignment: .leading, spacing: Spacing.m) {
                ForEach(Array(section.content.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Divider() }
                    row
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
            if !section.footer.isEmpty {
                section.footer
                    .font(.label)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }
}
