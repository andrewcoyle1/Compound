//
//  Activity+Sendable.swift
//  Compound
//
//  Created by Andrew Coyle on 16/09/2026.
//

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit

// ActivityKit's Activity is a thread-safe handle but the SDK does not mark it Sendable,
// so strict concurrency rejects update/end calls made from the main actor.
//
// Its own file rather than the top of LiveActivityManager.swift, which is already at the
// 750-line SwiftLint limit.
extension Activity: @retroactive @unchecked Sendable {}
#endif
