//
//  SwiftfulHaptics+Alias.swift
//  ArchitectureProject
//
//  Created by Nick Sarno on 1/12/25.
//

import SwiftfulHaptics

typealias HapticManager = SwiftfulHaptics.HapticManager
typealias HapticOption = SwiftfulHaptics.HapticOption

extension HapticLogType {
    
    var type: LogType {
        switch self {
        case .info:
            return .info
        case .analytic:
            return .analytic
        case .warning:
            return .warning
        case .severe:
            return .severe
        }
    }
    
}
extension LogManager: @retroactive HapticLogger {
    
    public func trackEvent(event: any HapticLogEvent) {
        trackEvent(eventName: event.eventName, parameters: event.parameters, type: event.type.type)
    }
    
}

extension CoreInteractor {
    // MARK: Haptics

    func prepareHaptic(option: HapticOption) {
        hapticManager.prepareHaptic(option: option)
    }

    func playHaptic(option: HapticOption) {
        hapticManager.playHaptic(option: option)
    }

    func tearDownHaptic(option: HapticOption) {
        hapticManager.tearDownHaptic(option: option)
    }

}
