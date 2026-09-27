//
//  StatItem.swift
//  DialedIn
//
//  Created by Andrew Coyle on 02/03/2026.
//

import SwiftUI

@available(*, deprecated, message: "Use Stat / Chip, see docs/specs/ui-framework/CONTRACT.md")
struct StatItem: View {
    
    var alignment: HorizontalAlignment = .leading
    var header: String
    var value: String
    
    var body: some View {
        Stat(value: value, label: header, size: .small, alignment: alignment)
    }
}
