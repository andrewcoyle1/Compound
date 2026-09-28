//
//  RowChipButton.swift
//  DialedIn
//

import SwiftUI

/// The trailing action on a settings row whose value is changed on another screen: "Edit" in
/// Program Settings and Exercise Settings, "Add" in Select Equipment. One style for what used to
/// be a radius-20 pill, a `.bordered` button and a grey capsule.
struct RowChipButton: View {
    let title: LocalizedStringKey
    /// What the action is for, so VoiceOver says "Edit, Name" rather than a bare "Edit".
    let subject: String
    let action: () -> Void

    init(_ title: LocalizedStringKey = "Edit", subject: String, action: @escaping () -> Void) {
        self.title = title
        self.subject = subject
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Chip(title)
        }
        .buttonStyle(.plain)
        .accessibilityHint(subject)
    }
}

#Preview {
    List {
        ListRow(title: "Name", subtitle: "Push Pull Legs", systemImage: Symbol.program, accessory: .custom(AnyView(RowChipButton(subject: "Name") { })))
        ListRow(title: "Resistance", subtitle: "Barbell", accessory: .custom(AnyView(RowChipButton("Add", subject: "Resistance") { })))
    }
}
