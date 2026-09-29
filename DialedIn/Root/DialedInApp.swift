//
//  DialedInApp.swift
//  DialedIn
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
            DialedInApp.main()
        }
    }
}

struct DialedInApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            if Utilities.isUITesting {
                AppViewForUITesting(container: delegate.dependencies.container)
            } else {
                delegate.builder.build()
            }
        }
        .commands {
            tabCommands
        }
    }

    /// Command-1 through Command-4 switch tabs, Command-F goes to Search — for iPad's hardware
    /// keyboard now, and reused by the Mac version later (Catalyst stays on; the rest of that
    /// build is deferred, see `docs/release-checklist.md`).
    @CommandsBuilder
    private var tabCommands: some Commands {
        CommandGroup(after: .toolbar) {
            Button(String(localized: "Dashboard")) { DeepLink.tab(.dashboard).post() }
                .keyboardShortcut("1", modifiers: .command)
            Button(String(localized: "Training")) { DeepLink.tab(.training).post() }
                .keyboardShortcut("2", modifiers: .command)
            Button(String(localized: "Nutrition")) { DeepLink.tab(.nutrition).post() }
                .keyboardShortcut("3", modifiers: .command)
            Button(String(localized: "Analytics")) { DeepLink.tab(.analytics).post() }
                .keyboardShortcut("4", modifiers: .command)
            Button(String(localized: "Search")) { DeepLink.tab(.search).post() }
                .keyboardShortcut("f", modifiers: .command)
        }
    }
}
