//
//  AppToast.swift
//  Compound
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Foundation

/// A short message shown over whatever the user happens to be looking at.
///
/// Raised through `NotificationCenter` rather than a router, because the thing worth saying is
/// often decided after the screen that decided it has gone: the workout tracker dismisses itself
/// before its save finishes, and the result of that save still has to reach the user.
///
/// Re-raising under the same `id` replaces the message in place, which is how one piece of work
/// reports its own progress — "retrying" becoming "saved" is one toast changing its mind, not two.
struct AppToast: Identifiable, Sendable, Equatable {

    enum Style: Sendable {
        case progress
        case success
        case failure
    }

    let id: String
    let style: Style
    let message: String
    let duration: Duration

    init(id: String = UUID().uuidString, style: Style, message: String, duration: Duration = .seconds(4)) {
        self.id = id
        self.style = style
        self.message = message
        self.duration = duration
    }
}

extension CoreInteractor {

    func showAppToast(_ toast: AppToast) {
        NotificationCenter.default.post(name: .appToast, object: toast)
    }
}
