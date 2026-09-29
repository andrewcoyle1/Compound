//
//  TabBarPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

@Observable
@MainActor
class TabBarPresenter {
    
    private let interactor: TabBarInteractor
    private let router: TabBarRouter

    var activeSession: WorkoutSessionModel? {
        interactor.activeSession
    }
    
    var draftMeal: MealLogModel? {
        interactor.draftMeal
    }
    
    /// Unread notification rows (a grouped row counts once), plus follow requests waiting on an
    /// answer, shown on the Dashboard tab since that is where the bell lives. Zero hides the badge.
    var unreadActivityCount: Int {
        NotificationGrouping.unreadGroupCount(interactor.activityNotifications) + interactor.incomingFollowRequests.count
    }

    var showTabAccessory: Bool {
        activeSession != nil || draftMeal != nil
    }
    
    var tabAccessoryWidth: CGFloat = 400

    /// Which tab is showing, keyed by `TabBarScreen.title`. Held here so a `compound://` link or a
    /// push notification can change it; the `TabView` had no selection binding at all before, so
    /// nothing outside the app could steer it.
    var selectedTabTitle: String = DeepLink.Tab.dashboard.title

    /// Applies a destination arriving from outside the app.
    func handle(_ deepLink: DeepLink) {
        switch deepLink {
        case .tab(let tab):
            interactor.trackEvent(
                eventName: "TabBarView_DeepLink_Tab",
                parameters: ["tab": tab.rawValue],
                type: .analytic
            )
            selectedTabTitle = tab.title
        case .session:
            interactor.trackEvent(
                eventName: "TabBarView_DeepLink_Session",
                parameters: nil,
                type: .analytic
            )
            // The Dashboard is where a session opens from; it hears the request and fetches it.
            selectedTabTitle = DeepLink.Tab.dashboard.title
            deepLink.post()
        case .notifications:
            interactor.trackEvent(
                eventName: "TabBarView_DeepLink_Notifications",
                parameters: nil,
                type: .analytic
            )
            // The bell lives on the Dashboard, so it opens the screen.
            selectedTabTitle = DeepLink.Tab.dashboard.title
            deepLink.post()
        case .join:
            interactor.trackEvent(
                eventName: "TabBarView_DeepLink_Join",
                parameters: nil,
                type: .analytic
            )
            // The Dashboard accepts the invite and opens the inviter's profile.
            selectedTabTitle = DeepLink.Tab.dashboard.title
            deepLink.post()
        case .workout:
            interactor.trackEvent(
                eventName: "TabBarView_DeepLink_Workout",
                parameters: ["has_active_session": activeSession != nil],
                type: .analytic
            )
            if activeSession != nil {
                router.showWorkoutTrackerView()
            } else {
                selectedTabTitle = DeepLink.Tab.dashboard.title
            }
        }
    }

    /// Unrecognised links are tracked and dropped rather than guessed at — landing somewhere
    /// arbitrary is worse than doing nothing.
    func onOpenURL(_ url: URL) {
        guard let deepLink = DeepLink(url: url) else {
            interactor.trackEvent(
                eventName: "TabBarView_DeepLink_Unrecognised",
                parameters: ["url": url.absoluteString],
                type: .warning
            )
            return
        }
        handle(deepLink)
    }

    /// The in-app counterpart to a deep link: same payload shape, no system prompt.
    func onSelectTabNotificationReceived(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let deepLink = DeepLink(pushUserInfo: userInfo)
        else {
            return
        }
        handle(deepLink)
    }

    /// A push tap never carries its payload here: `AppDelegate` parks it on `PushManager`, and this
    /// takes it. The same pull runs on appear, so a tap that launched the app is routed once the tab
    /// bar exists and the user is signed in, whichever comes last.
    func onPushNotificationReceived() {
        routePendingDeepLink()
    }

    func onViewAppear() {
        routePendingDeepLink()
    }

    private func routePendingDeepLink() {
        guard let deepLink = interactor.consumePendingDeepLink() else { return }
        handle(deepLink)
    }

    init(
        interactor: TabBarInteractor,
        router: TabBarRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
}
