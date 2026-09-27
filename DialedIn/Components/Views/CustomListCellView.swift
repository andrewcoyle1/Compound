//
//  CustomListCellView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/8/24.
//

import SwiftUI

/// Kept so existing call sites compile; drawn by `ListRow`. Call sites strip the List's row
/// formatting, so this keeps its own padding and surface until they move to `ListRow`.
/// `imageHeight`, `iconName`, `iconSize` and `verticalPadding` are ignored: the thumbnail and
/// selection indicator now come from `ListRow`.
@available(*, deprecated, message: "Use ListRow(title:subtitle:imageName:accessory:) or ListRow(title:subtitle:systemImage:accessory:), with .checkmark(_:) for selection")
struct CustomListCellView: View {

    private let imageName: String?
    private let sfSymbolName: String?
    private let title: String?
    private let subtitle: String?
    private let isSelected: Bool
    private let resizingMode: ContentMode

    init() {
        self.init(imageName: Constants.randomImage, title: "Alpha", subtitle: "An alien that is smiling in the park.")
    }

    init(
        imageName: String? = nil,
        sfSymbolName: String? = nil,
        imageHeight: CGFloat = 60,
        title: String? = nil,
        subtitle: String? = nil,
        isSelected: Bool = false,
        iconName: String = "person",
        iconSize: CGFloat = 24,
        resizingMode: ContentMode = .fill,
        verticalPadding: CGFloat = 4
    ) {
        self.imageName = imageName
        self.sfSymbolName = sfSymbolName
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.resizingMode = resizingMode
    }

    init(sfSymbolName: String, title: String? = nil, subtitle: String? = nil) {
        self.init(sfSymbolName: sfSymbolName, imageHeight: 30, title: title, subtitle: subtitle)
    }

    var body: some View {
        row
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .background(Color.surface)
            .contentShape(.rect)
    }

    @ViewBuilder
    private var row: some View {
        let accessory: ListRow.Accessory = isSelected ? .checkmark(true) : .none
        if imageName == nil, let sfSymbolName {
            ListRow(title: title ?? "", subtitle: subtitle, systemImage: sfSymbolName, accessory: accessory)
        } else {
            ListRow(title: title ?? "", subtitle: subtitle, imageName: imageName, resizingMode: resizingMode, accessory: accessory)
        }
    }
}
