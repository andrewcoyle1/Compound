//
//  CustomToggleView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 24/02/2026.
//

import SwiftUI

/// Kept so existing call sites compile; drawn by `ListRowToggle`.
@available(*, deprecated, message: "Use ListRowToggle(title:subtitle:systemImage:isOn:)")
struct CustomToggleView: View {

    let symbolName: String?
    let title: String
    let subtitle: String?
    let bool: Binding<Bool>

    init(
        symbolName: String? = nil,
        title: String,
        subtitle: String? = nil,
        bool: Binding<Bool>
    ) {
        self.symbolName = symbolName
        self.title = title
        self.subtitle = subtitle
        self.bool = bool
    }

    var body: some View {
        ListRowToggle(title: title, subtitle: subtitle, systemImage: symbolName, isOn: bool)
    }
}
