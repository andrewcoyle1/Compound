//
//  FlowLayout.swift
//  DialedIn
//

import SwiftUI

/// Lays its children out left to right, wrapping onto a new row when the next one would not fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { size(of: $0, maxWidth: maxWidth).height }.max() ?? 0 }
            .reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var yVal = bounds.minY
        for row in rows {
            var xVal = bounds.minX
            let rowHeight = row.map { size(of: $0, maxWidth: maxWidth).height }.max() ?? 0
            for subview in row {
                let size = size(of: subview, maxWidth: maxWidth)
                subview.place(at: CGPoint(x: xVal, y: yVal), proposal: ProposedViewSize(size))
                xVal += size.width + spacing
            }
            yVal += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubview]] = [[]]
        var rowWidth: CGFloat = 0

        for subview in subviews {
            let size = size(of: subview, maxWidth: maxWidth)
            if rowWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(subview)
            rowWidth += size.width + spacing
        }
        return rows
    }

    /// A subview's ideal size, but never wider than the layout: an item wider than the row, such
    /// as a long record at a large text size, wraps or truncates inside it instead of running
    /// off the edge.
    private func size(of subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        guard ideal.width > maxWidth else { return ideal }
        return subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
    }
}
