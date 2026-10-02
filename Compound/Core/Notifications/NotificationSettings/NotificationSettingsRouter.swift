//
//  NotificationSettingsRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 29/09/2026.
//

/// The screen only raises alerts, which `GlobalRouter` already provides.
@MainActor
protocol NotificationSettingsRouter: GlobalRouter { }

extension CoreRouter: NotificationSettingsRouter { }
