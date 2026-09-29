import SwiftUI

@MainActor
protocol ShortcutsRouter: GlobalRouter {
    
}

extension CoreRouter: ShortcutsRouter { }
