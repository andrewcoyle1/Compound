//
//  NotificationSettingsInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 29/09/2026.
//

import UserNotifications

@MainActor
protocol NotificationSettingsInteractor: GlobalInteractor {
    var isAuthorised: UNAuthorizationStatus { get }
    var privateUserSettings: PrivateUserSettings { get }
    func checkPushNotificationAuthorisation() async throws -> UNAuthorizationStatus
    func requestPushAuthorisation() async throws -> Bool
    func updateSocialNotificationPreferences(type: ActivityNotificationModel.ActivityType, isEnabled: Bool) async throws
    func updatePrivateUserSettings(_ change: (inout PrivateUserSettings) -> Void) async throws
    func setComeBackReminders(isEnabled: Bool) async throws
    func setMealReminders(isEnabled: Bool) async throws
}

extension CoreInteractor: NotificationSettingsInteractor { }
