//
//  Presentation.swift
//  Compound
//

import SwiftUI

/// Sheet presets. Present through `router.showScreen(.sheetConfig(config: .half))`.
///
/// Every preset includes `.large`, so content can never be trapped at large Dynamic Type sizes,
/// and the drag indicator is always visible. Plain `.sheet` (full height, no detents) stays allowed.
///
/// | Preset | Detents |
/// |---|---|
/// | `.compact` | `[.fraction(0.35), .large]` |
/// | `.half` | `[.medium, .large]` |
/// | `.full` | `[.large]` |
///
/// Haptics are not a token. A presenter calls `interactor.playHaptic(option: .success)` after every
/// successful save, log, complete or finish, `.error` when one fails, and `.selection` for picker
/// and segment changes. No raw `UI*FeedbackGenerator`s.
extension ResizableSheetConfig {
    static var compact: ResizableSheetConfig {
        ResizableSheetConfig(detents: [.fraction(0.35), .large], dragIndicator: .visible)
    }

    static var half: ResizableSheetConfig {
        ResizableSheetConfig(detents: [.medium, .large], dragIndicator: .visible)
    }

    static var full: ResizableSheetConfig {
        ResizableSheetConfig(detents: [.large], dragIndicator: .visible)
    }
}
