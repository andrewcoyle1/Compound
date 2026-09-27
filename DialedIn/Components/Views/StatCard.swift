//
//  StatCard.swift
//  DialedIn
//
//  Created by Andrew Coyle on 19/10/2025.
//

import SwiftUI

@available(*, deprecated, message: "Use Stat / Chip, see docs/specs/ui-framework/CONTRACT.md")
struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color?
    let alignment: HorizontalAlignment
    
    init(
        value: String,
        label: String,
        icon: String = "plus",
        color: Color? = nil,
        alignment: HorizontalAlignment = .leading
    ) {
        self.value = value
        self.label = label
        self.icon = icon
        self.color = color
        self.alignment = alignment
    }
    
    var body: some View {
        Stat(value: value, label: label, systemImage: icon, size: .medium, alignment: alignment, tint: color)
    }
}
