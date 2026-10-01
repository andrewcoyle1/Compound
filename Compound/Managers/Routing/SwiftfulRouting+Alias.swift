//
//  SwiftfulRouting+Alias.swift
//  Compound
//
//  Created by Andrew Coyle on 29/01/2026.
//

import SwiftUI
import SwiftfulRouting

typealias RouterView = SwiftfulRouting.RouterView
typealias AnyDestination = SwiftfulRouting.AnyDestination
typealias AnyRouter = SwiftfulRouting.AnyRouter
typealias AlertStyle = SwiftfulRouting.AlertStyle
typealias ResizableSheetConfig = SwiftfulRouting.ResizableSheetConfig
typealias PresentationDetentTransformable = SwiftfulRouting.PresentationDetentTransformable

/// Hands `content` the enclosing `RouterView`'s router, for shared views that navigate without a
/// router of their own. Here so those views needn't import SwiftfulRouting to read it.
struct RouterReader<Content: View>: View {
    @Environment(\.router) private var router
    @ViewBuilder let content: (AnyRouter) -> Content

    var body: some View {
        content(router)
    }
}

extension RoutingLogType {

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
extension LogManager: @retroactive RoutingLogger {
    public func trackEvent(event: any RoutingLogEvent) {
        trackEvent(eventName: event.eventName, parameters: event.parameters, type: event.type.type)
    }

    public func trackScreenView(event: any RoutingLogEvent) {
        trackScreenView(event: AnyLoggableEvent(eventName: event.eventName, parameters: event.parameters, type: event.type.type))
    }
}
