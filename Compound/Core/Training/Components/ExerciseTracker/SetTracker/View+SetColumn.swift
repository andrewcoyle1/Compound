//
//  View+SetColumn.swift
//  Compound
//
//  The set table's column frame, shared by the rows and their headings.
//

import SwiftUI

extension View {
    /// A column of the set table: its fixed width, or on the stacked row at accessibility sizes a
    /// share of the line that grows with the text. The headers use the same widths.
    @ViewBuilder
    func setColumn(width: CGFloat, height: CGFloat? = nil, stretches: Bool, alignment: Alignment = .center) -> some View {
        if stretches {
            frame(maxWidth: .infinity, minHeight: height, alignment: alignment)
        } else {
            frame(width: width, height: height, alignment: .center)
        }
    }
}
