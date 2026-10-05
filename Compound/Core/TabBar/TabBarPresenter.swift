//
//  TabBarPresenter.swift
//  Compound
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
    
    /// Unread comments and mentions (a grouped row counts once), plus follow requests waiting on an
    /// answer, shown on the Social tab since that is where the bell lives. Zero hides the badge.
    /// Likes, follows and the rest wait in Notifications: a badge is for something to answer.
    var unreadActivityCount: Int {
        let needsAnswer = interactor.activityNotifications.filter { $0.type == .comment || $0.type == .mention }
        return NotificationGrouping.unreadGroupCount(needsAnswer) + interactor.incomingFollowRequests.count
    }

    var showTabAccessory: Bool {
        activeSession != nil || draftMeal != nil
    }

    /// Which tab is showing. Held here so a `compound://` link or a push notification can change
    /// it. Keyed by the tab itself, not its title: the titles are translated, so in Spanish a
    /// title key never matched "Dashboard" and links selected nothing.
    var selectedTab: DeepLink.Tab = .today

    /// Applies a destination arriving from outside the app.
    func handle(_ deepLink: DeepLink) {
        switch deepLink {
        case .tab(let tab):
            interactor.trackEvent(
                eventName: "TabBarView_DeepLink_Tab",
                parameters: ["tab": tab.rawValue],
                type: .analytic
            )
            selectedTab = tab
        case .session:
            interactor.trackEvent(
                eventName: "TabBarView_DeepLink_Session",
                parameters: nil,
                type: .analytic
            )
            // Social is where a session opens from; it hears the request and fetches it.
            selectedTab = .social
            deepLink.post()
        case .notifications:
            interactor.trackEvent(
                eventName: "TabBarView_DeepLink_Notifications",
                parameters: nil,
                type: .analytic
            )
            // The bell lives on Social, so it opens the screen.
            selectedTab = .social
            deepLink.post()
        case .join:
            interactor.trackEvent(
                eventName: "TabBarView_DeepLink_Join",
                parameters: nil,
                type: .analytic
            )
            // Social accepts the invite and opens the inviter's profile.
            selectedTab = .social
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
                selectedTab = .today
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

    /// `restoredTab` is the tab the scene was on when the app last closed. A pending link, routed
    /// after it, still wins. The Appear is the app shell's: each tab root logs its own, so this
    /// counts arrivals in the main app rather than screens.
    func onViewAppear(restoredTab: DeepLink.Tab? = nil) {
        interactor.trackScreenEvent(event: Event.onAppear)
        if let restoredTab { selectedTab = restoredTab }
        routePendingDeepLink()
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    /// A tab the user picked. Re-tapping the current tab (which pops it to its root) is not a
    /// change of tab, so it is not counted.
    func onTabSelected(_ tab: DeepLink.Tab) {
        if tab != selectedTab {
            interactor.trackEvent(event: Event.tabSelected(tab: tab))
        }
        selectedTab = tab
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

extension TabBarPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case tabSelected(tab: DeepLink.Tab)

        var eventName: String {
            switch self {
            case .onAppear:    return "TabBarView_Appear"
            case .onDisappear: return "TabBarView_Disappear"
            case .tabSelected: return "TabBarView_Tab_Selected"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .tabSelected(let tab): return ["tab": tab.rawValue]
            default:                    return nil
            }
        }

        var type: LogType { .analytic }
    }
}
