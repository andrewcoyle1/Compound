//
//  CustomLabelButtonView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 24/02/2026.
//

import SwiftUI

/// Kept so existing call sites compile; drawn by `ListRow` with the caller's trailing content.
/// Its action lives inside that content, so only the content is tappable. `ListRowButton` makes the
/// whole row the tap target.
@available(*, deprecated, message: "Use ListRowButton(title:subtitle:systemImage:action:) for a row that opens something, or ListRow(accessory: .value/.custom) for a display row")
struct CustomLabelButtonView<Content: View>: View {

    let symbolName: String?
    let title: String
    let subtitle: String?
    var content: (() -> Content)?

    init(
        symbolName: String? = nil,
        title: String,
        subtitle: String? = nil,
        content: (() -> Content)? = nil
    ) {
        self.symbolName = symbolName
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        ListRow(
            title: title,
            subtitle: subtitle,
            systemImage: symbolName,
            accessory: content.map { .custom(AnyView($0())) } ?? .none
        )
    }
}
