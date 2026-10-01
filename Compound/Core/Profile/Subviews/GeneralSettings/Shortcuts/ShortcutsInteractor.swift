import SwiftUI

@MainActor
protocol ShortcutsInteractor: GlobalInteractor {
    var shortcutSettings: ShortcutSettings { get }
    func saveShortcutSettings(_ settings: ShortcutSettings) async throws
}

extension CoreInteractor: ShortcutsInteractor { }
