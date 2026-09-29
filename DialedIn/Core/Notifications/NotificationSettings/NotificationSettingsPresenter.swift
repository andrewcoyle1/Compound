//
//  NotificationSettingsPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 29/09/2026.
//

import Foundation

@Observable
@MainActor
class NotificationSettingsPresenter {
    let interactor: NotificationSettingsInteractor
    let router: NotificationSettingsRouter
    
    init(interactor: NotificationSettingsInteractor, router: NotificationSettingsRouter) {
        self.interactor = interactor
        self.router = router
    }
}
