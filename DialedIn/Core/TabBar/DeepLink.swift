//
//  DeepLink.swift
//  DialedIn
//

import Foundation

/// A destination the app can be sent to from outside it — a `compound://` URL or a push
/// notification payload.
///
/// `AnalyticsPresenter.handleDeepLink` used to parse a URL's query items into a loop whose body was
/// `// Do something with value`, and `handlePushNotificationRecieved` did the same over the payload.
/// Both fired analytics and navigated nowhere, and the `compound` scheme in Info.plist had no
/// destinations behind it at all.
enum DeepLink: Equatable {

    case tab(Tab)

    /// One workout session, from a like, comment or mention push. Lands on Social, which then
    /// opens it — with its comments on top when `openComments` is set.
    case session(id: String, authorId: String, openComments: Bool)

    /// The notifications screen, from a follow-request push. Lands on Social, which opens it from
    /// its bell.
    case notifications

    /// `compound://join/<code>`, an invite a friend sent. Lands on Social, which accepts it and
    /// opens the inviter's profile. The code is already normalised by `InviteCode`.
    case join(code: String)

    /// `compound://workout`, from the Today's Workout widget. Opens the tracker when a session is
    /// under way, otherwise Today, whose workout card starts one.
    case workout

    /// The tab bar's roots, and the `TabView`'s selection. One job each: Today is what to do now,
    /// Training and Nutrition are the plan and the library for each, Progress is the trends, and
    /// Social is everyone else.
    enum Tab: String, CaseIterable, Identifiable {
        case today
        case training
        case nutrition
        case progress
        case social

        /// Names from before the tabs were split by job still land somewhere sensible: links,
        /// push payloads and a restored scene can all carry them. "dashboard" held both Today and
        /// Social, and Today is the default; "search" (once "add") was a launcher for what Today
        /// now holds.
        init?(name: String) {
            switch name {
            case "dashboard", "search", "add": self = .today
            case "analytics": self = .progress
            default: self.init(rawValue: name)
            }
        }

        var id: String { rawValue }
    }

    /// Parses `compound://tab/nutrition`, and tolerates `compound://tab?name=nutrition` because the
    /// old handler read query items and someone may have links in that shape.
    ///
    /// Returns nil for anything unrecognised rather than guessing — an unknown link should do
    /// nothing visible, not land somewhere arbitrary.
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        let host = components.host?.lowercased()
        let firstPath = components.path
            .split(separator: "/")
            .first
            .map { String($0).lowercased() }
        let queryName = components.queryItems?
            .first { $0.name.lowercased() == "name" || $0.name.lowercased() == "tab" }?
            .value?
            .lowercased()

        if host == "join" {
            guard let raw = firstPath, let code = InviteCode.normalised(raw) else { return nil }
            self = .join(code: code)
            return
        }
        if host == "workout" {
            self = .workout
            return
        }
        guard host == "tab" else { return nil }
        guard let name = firstPath ?? queryName, let tab = Tab(name: name) else { return nil }
        self = .tab(tab)
    }

    /// Asks the tab bar to show this destination from inside the app — the Dashboard's empty feed
    /// sending you to Social's people search, for one. Goes through `NotificationCenter` rather
    /// than the `compound://` scheme so iOS does not prompt to open the app from itself.
    func post() {
        switch self {
        case .tab(let tab):
            NotificationCenter.default.post(
                name: Constants.selectTab,
                object: nil,
                userInfo: ["tab": tab.rawValue]
            )
        case .session(let id, let authorId, let openComments):
            NotificationCenter.default.post(
                name: Constants.openWorkoutSession,
                object: nil,
                userInfo: ["session_id": id, "session_author_id": authorId, "type": openComments ? "comment" : "like"]
            )
        case .notifications:
            NotificationCenter.default.post(name: Constants.openNotifications, object: nil)
        case .join(let code):
            NotificationCenter.default.post(name: Constants.acceptInvite, object: nil, userInfo: ["code": code])
        case .workout:
            NotificationCenter.default.post(
                name: Constants.selectTab,
                object: nil,
                userInfo: ["deep_link": WidgetSnapshotStore.workoutURL.absoluteString]
            )
        }
    }

    /// The same destinations from a push payload, so a notification tap and a link agree on what
    /// they mean. Reads `deep_link` as a full URL string, then `session_id` with
    /// `session_author_id` (both non-empty) as a session, then `tab` as a bare name. A
    /// `follow_request` type opens the notifications screen, where the request is answered.
    init?(pushUserInfo: [AnyHashable: Any]) {
        if let link = pushUserInfo["deep_link"] as? String, let url = URL(string: link) {
            self.init(url: url)
            return
        }
        if pushUserInfo["type"] as? String == "follow_request" {
            self = .notifications
            return
        }
        if let id = pushUserInfo["session_id"] as? String, !id.isEmpty,
           let authorId = pushUserInfo["session_author_id"] as? String, !authorId.isEmpty {
            let type = pushUserInfo["type"] as? String
            self = .session(id: id, authorId: authorId, openComments: type == "comment" || type == "mention")
            return
        }
        if let name = (pushUserInfo["tab"] as? String)?.lowercased(), let tab = Tab(name: name) {
            self = .tab(tab)
            return
        }
        return nil
    }
}
