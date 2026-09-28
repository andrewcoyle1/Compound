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
    
    /// The id of the toast that says the app cannot reach the server, so a later success can take
    /// exactly that one down.
    static let connectionToastId = "app_connection"

    /// How long to wait before retry number `attempt` (0-based): 5 s, doubling, capped at a minute.
    /// It used to retry every five seconds for ever.
    static func retryDelay(attempt: Int) -> Duration {
        .seconds(min(5 * (1 << min(attempt, 4)), 60))
    }

    func checkUserStatus(attempt: Int = 0) async {
        if let user = interactor.auth {
            // User is authenticated
            interactor.trackEvent(event: Event.existingAuthStart)
            
            do {
                try await interactor.logIn(user: user, isNewUser: false)
                interactor.trackEvent(event: Event.existingAuthSuccess)
                onConnected()
            } catch {
                interactor.trackEvent(event: Event.existingAuthFail(error: error))
                await retryAfterFailure(attempt: attempt)
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
                onConnected()

                // Save push token
                if let token = try? await Messaging.messaging().token() {
                    savePushToken(token: token)
                }
                
            } catch {
                interactor.trackEvent(event: Event.anonAuthFail(error: error))
                await retryAfterFailure(attempt: attempt)
            }
        }
    }

    /// A first launch with no connection used to leave Welcome's button greyed out with no reason
    /// given. The first failure now says why, and stays up until the app gets through.
    private func retryAfterFailure(attempt: Int) async {
        if attempt == 0 {
            interactor.showAppToast(AppToast(
                id: Self.connectionToastId,
                style: .failure,
                message: String(localized: "Can't reach the server. Check your connection.")
            ))
        }
        try? await Task.sleep(for: Self.retryDelay(attempt: attempt))
        await checkUserStatus(attempt: attempt + 1)
    }

    private func onConnected() {
        if toast?.id == Self.connectionToastId { toast = nil }
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

    /// The banner opens Notifications, where the activity it announced is.
    func onActivityBannerPressed() {
        activityBanner = nil
        DeepLink.tab(.dashboard).post()
        DeepLink.notifications.post()
    }

    func onActivityBannerDismissed() {
        activityBanner = nil
    }

    /// A failure toast carries an instruction ("resume it from Training"), so it stays until the
    /// person dismisses it. The others still time out.
    func onAppToast(notification: Notification) {
        guard let toast = notification.object as? AppToast else { return }
        self.toast = toast
        toastGeneration += 1
        guard toast.style != .failure else { return }
        let generation = toastGeneration
        Task {
            try? await Task.sleep(for: toast.duration)
            if toastGeneration == generation { self.toast = nil }
        }
    }

    func onToastDismissed() {
        toast = nil
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
