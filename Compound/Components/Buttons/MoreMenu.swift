//
//  MoreMenu.swift
//  Compound
//
//  Created by Andrew Coyle on 14/10/2026.
//

import SwiftUI

struct MoreMenu<MenuContent: View>: View {

    var content: () -> MenuContent

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: Symbol.more)
                .padding(4)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
    }
}

#Preview {
    List {
        Section {
            Label("Add", systemImage: "plus")
        } header: {
            HStack {
                Text("Header")
                Spacer()
                MoreMenu {
                    Group {
                        Button("Example 1") { }
                        Button("Example 2") { }
                        Button("Example 3") { }
                    }
                }
            }
        }
    }
}
