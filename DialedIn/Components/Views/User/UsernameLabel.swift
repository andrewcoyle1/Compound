//
//  UsernameLabel.swift
//  DialedIn
//
//  `@handle` under a person's name. Every surface that shows one goes through this, so they all
//  read the same; nothing is drawn for someone who has not picked a handle.
//

import SwiftUI

struct UsernameLabel: View {

    let username: String?
    var font: Font = .caption

    var body: some View {
        if let username, !username.isEmpty {
            Text(verbatim: "@\(username)")
                .font(font)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        UsernameLabel(username: "bob_lifts")
        UsernameLabel(username: nil)
    }
}
