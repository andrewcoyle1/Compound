//
//  OverallTargetCellView.swift
//  Compound
//
//  Created by Andrew Coyle on 26/10/2025.
//

import SwiftUI

/// The week's total for one metric against the week's target, at the end of its grid row.
struct OverallTargetCellView: View {
    let systemImage: String
    let tint: Color
    /// Already formatted with its unit, e.g. "1,150 g".
    let valueText: String
    let targetText: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(valueText)
            }
            .font(.metricSmall)
            Text("of \(targetText)")
                .font(.label)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    OverallTargetCellView(systemImage: Symbol.protein, tint: .protein, valueText: "1,150 g", targetText: "1,058 g")
}
