//
//  CompoundApp.swift
//  Compound
//
//  Created by Andrew Coyle on 19/08/2025.
//

import SwiftUI

@main
struct AppEntryPoint {

    /// Entry point is either (1) empty build for Unit Testing or (2) actual app.
    static func main() {
        if Utilities.isUnitTesting {
            AppViewForUnitTesting.main()
        } else {
            CompoundApp.main()
        }
    }
}

struct CompoundApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            if Utilities.isUITesting {
                AppViewForUITesting(container: delegate.dependencies.container)
            } else {
                delegate.builder.build()
            }
        }
        // Every routed screen centres its scroll content at this width when it is wider.
        .environment(\.readableContentWidth, ContentWidth.readable)
        .commands {
            tabCommands
        }
    }

    /// Command-1 through Command-5 switch tabs — for iPad's hardware keyboard now, and reused by
    /// the Mac version later (Catalyst stays on; the rest of that build is deferred, see
    /// `docs/release-checklist.md`). Search is inside each tab, where its field takes focus.
    @CommandsBuilder
    private var tabCommands: some Commands {
        CommandGroup(after: .toolbar) {
            Button(String(localized: "Today")) { DeepLink.tab(.today).post() }
                .keyboardShortcut("1", modifiers: .command)
            Button(String(localized: "Training")) { DeepLink.tab(.training).post() }
                .keyboardShortcut("2", modifiers: .command)
            Button(String(localized: "Nutrition")) { DeepLink.tab(.nutrition).post() }
                .keyboardShortcut("3", modifiers: .command)
            Button(String(localized: "Progress")) { DeepLink.tab(.progress).post() }
                .keyboardShortcut("4", modifiers: .command)
            Button(String(localized: "Social")) { DeepLink.tab(.social).post() }
                .keyboardShortcut("5", modifiers: .command)
        }
    }
}
