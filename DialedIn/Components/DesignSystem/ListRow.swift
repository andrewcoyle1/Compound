//
//  ListRow.swift
//  DialedIn
//
//  The one list row. `ListRow` draws content only; it has no background, because inside a `List`
//  the row supplies it. `ListRowButton`, `ListRowToggle` and `SelectableRow` wrap it for the three
//  interactive cases.
//
//  Dynamic Type: every text uses a text-style token and wraps, the only size constraint is the
//  44 pt minimum tap target, and the leading glyph and thumbnail scale with `@ScaledMetric`. At the
//  accessibility sizes a `.value` or `.custom` accessory moves under the title instead of squeezing
//  it into a letter-per-line column.
//

import SwiftUI

struct ListRow: View {

    enum Accessory {
        case none
        /// A disclosure chevron: the row opens another screen.
        case chevron
        /// A selection indicator: a filled check in the accent when selected, an empty circle when
        /// not. The row gains the `.isSelected` trait when selected.
        case checkmark(Bool)
        /// A trailing value in secondary text.
        case value(String)
        case custom(AnyView)
    }

    private enum Leading {
        case none
        case symbol(String)
        /// A remote URL or bundled asset name; `nil` draws a placeholder so rows stay aligned.
        case image(String?, ContentMode)
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var iconSide = ControlSize.icon
    @ScaledMetric(relativeTo: .body) private var thumbnailSide = ControlSize.thumbnail

    let title: String
    let subtitle: String?
    private let leading: Leading
    private let tint: AnyShapeStyle
    let accessory: Accessory

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        tint: Color? = nil,
        accessory: Accessory = .none
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = systemImage.map(Leading.symbol) ?? .none
        self.tint = tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.tint)
        self.accessory = accessory
    }

    /// A row led by a thumbnail: a remote URL or a bundled asset name. `nil` shows a placeholder.
    init(
        title: String,
        subtitle: String? = nil,
        imageName: String?,
        resizingMode: ContentMode = .fill,
        accessory: Accessory = .none
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = .image(imageName, resizingMode)
        self.tint = AnyShapeStyle(.tint)
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: Spacing.m) {
            leadingView
            AdaptiveStack(horizontalAlignment: .leading, spacing: Spacing.s) {
                titles
                inlineAccessory
            }
            trailingAccessory
        }
        // No minHeight here: List already enforces a 44 pt minimum row and adds its own vertical
        // insets, so a second minimum on the content made every settings row ~60 pt tall.
        .modifier(SelectionTrait(accessory: accessory))
    }

    // MARK: Leading

    @ViewBuilder
    private var leadingView: some View {
        switch leading {
        case .none:
            EmptyView()
        case .symbol(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .foregroundStyle(tint)
                .frame(width: iconSide, height: iconSide)
                .accessibilityHidden(true)
        case .image(let name, let mode):
            Group {
                if let name {
                    ImageLoaderView(urlString: name, resizingMode: mode)
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: thumbnailSide, height: thumbnailSide)
            .clipShape(.rect(cornerRadius: Radius.s, style: .continuous))
            .accessibilityHidden(true)
        }
    }

    // MARK: Titles

    private var titles: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(.rowTitle)
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                    // Capped only below the accessibility sizes, where two lines still say enough.
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Accessories

    /// Accessories wide enough to squeeze the title: they sit beside it, or under it at the
    /// accessibility sizes.
    @ViewBuilder
    private var inlineAccessory: some View {
        switch accessory {
        case .value(let value):
            Text(value)
                .font(.rowTitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
        case .custom(let view):
            view
        case .none, .chevron, .checkmark:
            EmptyView()
        }
    }

    /// Glyph accessories: always trailing.
    @ViewBuilder
    private var trailingAccessory: some View {
        switch accessory {
        case .chevron:
            Image(systemName: "chevron.forward")
                .font(.rowDetail.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        case .checkmark(let isSelected):
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .iconSize(.small)
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .accessibilityHidden(true)
        case .none, .value, .custom:
            EmptyView()
        }
    }
}

/// A `.checkmark` row reads as one element carrying the selected state. Other rows keep their
/// children separate, so a `.custom` accessory's button stays reachable.
private struct SelectionTrait: ViewModifier {
    let accessory: ListRow.Accessory

    func body(content: Content) -> some View {
        if case .checkmark(let isSelected) = accessory {
            content
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            content
        }
    }
}

// MARK: - ListRowButton

/// A row that opens something. The **whole row** is the tap target, and it keeps the native List
/// highlight: do not give it `.plain` inside a List.
struct ListRowButton: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var tint: Color?
    var accessory: ListRow.Accessory = .chevron
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        tint: Color? = nil,
        accessory: ListRow.Accessory = .chevron,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.accessory = accessory
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ListRow(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint, accessory: accessory)
                .contentShape(.rect)
        }
    }
}

// MARK: - ListRowToggle

/// A `Toggle` whose label is a `ListRow`.
struct ListRowToggle: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    @Binding var isOn: Bool

    init(title: String, subtitle: String? = nil, systemImage: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self._isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            ListRow(title: title, subtitle: subtitle, systemImage: systemImage)
        }
    }
}

// MARK: - SelectableRow

/// One option in a choice list: the whole row is a button, the checkmark shows the choice, and the
/// row carries `.isSelected` for VoiceOver.
struct SelectableRow: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    init(title: String, subtitle: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ListRow(title: title, subtitle: subtitle, accessory: .checkmark(isSelected))
                .contentShape(.rect)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Previews

private struct ListRowPreview: View {
    @State private var isOn = true
    @State private var choice = 1

    var body: some View {
        List {
            Section("Accessories") {
                ListRow(title: "None", subtitle: "A plain row with a subtitle", systemImage: Symbol.workout)
                ListRow(title: "Chevron", systemImage: Symbol.settings, accessory: .chevron)
                ListRow(title: "Checkmark", systemImage: Symbol.exercise, accessory: .checkmark(true))
                ListRow(title: "Value", systemImage: Symbol.scaleWeight, tint: .Metric.scaleWeight, accessory: .value("82.5 kg"))
                ListRow(title: "Custom", subtitle: "Trailing view of the caller's choosing", systemImage: Symbol.rest, accessory: .custom(AnyView(Button("Edit") { }.buttonStyle(.glass))))
                ListRow(title: "Thumbnail", subtitle: "Bench Press, Squat, Deadlift", imageName: Constants.randomImage, accessory: .chevron)
                ListRow(title: "No image", subtitle: "A placeholder keeps rows aligned", imageName: nil)
            }
            Section("Button") {
                ListRowButton(title: "Rest Timer", subtitle: "The whole row is tappable", systemImage: Symbol.rest) { }
            }
            Section("Toggle") {
                ListRowToggle(title: "Keep Alive", subtitle: "Keep your phone awake during active workout sessions", systemImage: Symbol.duration, isOn: $isOn)
            }
            Section("Selectable") {
                ForEach(0..<3) { index in
                    SelectableRow(title: "Option \(index + 1)", subtitle: "What this option means", isSelected: choice == index) {
                        choice = index
                    }
                }
            }
        }
    }
}

#Preview("ListRow, light") {
    ListRowPreview().preferredColorScheme(.light)
}

#Preview("ListRow, dark") {
    ListRowPreview().preferredColorScheme(.dark)
}

#Preview("ListRow, xSmall") {
    ListRowPreview().dynamicTypeSize(.xSmall)
}

#Preview("ListRow, large") {
    ListRowPreview().dynamicTypeSize(.large)
}

#Preview("ListRow, accessibility3") {
    ListRowPreview().dynamicTypeSize(.accessibility3)
}

#Preview("ListRow, accessibility5") {
    ListRowPreview().dynamicTypeSize(.accessibility5)
}
