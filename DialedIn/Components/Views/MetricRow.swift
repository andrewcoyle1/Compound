//
//  MetricRow.swift
//  DialedIn
//
//  Created by Andrew Coyle on 20/10/2025.
//

import SwiftUI

/// Kept so existing call sites compile; drawn by `ListRow`.
@available(*, deprecated, message: "Use ListRow(title:systemImage:accessory: .value(_:))")
struct MetricRow: View {
    let label: String
    let value: String
    let icon: String?

    init(label: String, value: String, icon: String? = nil) {
        self.label = label
        self.value = value
        self.icon = icon
    }

    var body: some View {
        ListRow(title: label, systemImage: icon, accessory: .value(value))
    }
}
