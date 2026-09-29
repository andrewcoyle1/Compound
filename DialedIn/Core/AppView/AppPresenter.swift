//
//  AppPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/10/2025.
//

import Foundation
import FirebaseMessaging

@Observable
@MainActor
class AppPresenter {
    private let interactor: AppInteractor
    
    var activeModuleId: String {
        interactor.startingModuleId
    }

    var auth: UserAuthInfo? {
        interactor.auth
    }

    var activityBanner: ActivityNotificationModel?

    /// The app-level toast, raised from anywhere via `.appToast` so it can outlive the screen that
    /// asked for it.
    var toast: AppToast?

    /// The toast's auto-dismiss is keyed on a generation rather than the toast's id, because one
    /// piece of work deliberately re-raises under the same id as it progresses. An id-keyed timer
    /// from "retrying" would pull the "saved" that replaced it straight back off the screen.
    private var toastGeneration = 0
    
    init(interactor: AppInteractor) {
        self.interactor = interactor
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
    
    func schedulePushNotifications() {
        interactor.schedulePushNotificationsForNextWeek()
    }
    
    func checkUserStatus() async {
        if let user = interactor.auth {
            // User is authenticated
            interactor.trackEvent(event: Event.existingAuthStart)
            
            do {
                try await interactor.logIn(user: user, isNewUser: false)
                interactor.trackEvent(event: Event.existingAuthSuccess)
            } catch {
                interactor.trackEvent(event: Event.existingAuthFail(error: error))
                try? await Task.sleep(for: .seconds(5))
                await checkUserStatus()
            }
        } else {
            
            // User is not authenticated
            interactor.trackEvent(event: Event.anonAuthStart)

            do {
                let result = try await interactor.signInAnonymously()
                
                // log in to app
                interactor.trackEvent(event: Event.anonAuthSuccess)
                
                // Log in
                try await interactor.logIn(user: result.user, isNewUser: result.isNewUser)
                
                // Save push token
                if let token = try? await Messaging.messaging().token() {
                    savePushToken(token: token)
                }
                
            } catch {
                interactor.trackEvent(event: Event.anonAuthFail(error: error))
                try? await Task.sleep(for: .seconds(5))
                await checkUserStatus()
            }
        }
    }

    func onNewActivityNotification(notification: Notification) {
        guard let notif = notification.object as? ActivityNotificationModel else { return }
        activityBanner = notif
        let id = notif.id
        Task {
            try? await Task.sleep(for: .seconds(4))
            if activityBanner?.id == id { activityBanner = nil }
        }
    }

    func onAppToast(notification: Notification) {
        guard let toast = notification.object as? AppToast else { return }
        self.toast = toast
        toastGeneration += 1
        let generation = toastGeneration
        Task {
            try? await Task.sleep(for: toast.duration)
            if toastGeneration == generation { self.toast = nil }
        }
    }

    func onFCMTokenRecieved(notification: Notification) {
        guard let token = NotificationCenter.default.getFCMToken(notification: notification) else {
            // Token not found in notification
            interactor.trackEvent(event: Event.fcmFail(error: AppPresenterError.fcmTokenNotFound))
            return
        }
        savePushToken(token: token)
    }
    
    private func savePushToken(token: String) {
        interactor.trackEvent(event: Event.fcmStart)
        
        Task {
            do {
                try await interactor.saveUserFCMToken(token: token)
                interactor.trackEvent(event: Event.fcmSuccess)
            } catch {
                interactor.trackEvent(event: Event.fcmFail(error: error))
            }
        }
    }
    
    enum AppPresenterError: LocalizedError {
        case fcmTokenNotFound
    }

}

extension AppPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case existingAuthStart
        case existingAuthSuccess
        case existingAuthFail(error: Error)
        case anonAuthStart
        case anonAuthSuccess
        case anonAuthFail(error: Error)
        case fcmStart
        case fcmSuccess
        case fcmFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:             return "AppView_Appear"
            case .onDisappear:          return "AppView_Disappear"
            case .existingAuthStart:    return "AppView_ExistingAuth_Start"
            case .existingAuthSuccess:  return "AppView_ExistingAuth_Success"
            case .existingAuthFail:     return "AppView_ExistingAuth_Fail"
            case .anonAuthStart:        return "AppView_AnonAuth_Start"
            case .anonAuthSuccess:      return "AppView_AnonAuth_Success"
            case .anonAuthFail:         return "AppView_AnonAuth_Fail"
            case .fcmStart:             return "AppView_FCM_Start"
            case .fcmSuccess:           return "AppView_FCM_Success"
            case .fcmFail:              return "AppView_FCM_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .existingAuthFail(error: let error), .anonAuthFail(error: let error), .fcmFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .existingAuthFail, .anonAuthFail, .fcmFail:
                return .severe
            default:
                return .analytic

            }
        }
    }
}
