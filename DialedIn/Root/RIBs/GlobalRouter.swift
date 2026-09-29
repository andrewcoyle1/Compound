//
//  GlobalRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 04/12/2025.
//

import SwiftUI

@MainActor
protocol GlobalRouter {
    var router: AnyRouter { get }

    // Alerts are protocol requirements rather than extension-only helpers so that a test double can
    // substitute its own implementation. Several destructive flows (delete, discard, clear day) only
    // do their work inside an alert button, and a statically dispatched helper made those unreachable
    // from a test. The default implementations below keep the behaviour identical for real routers.
    func showAlert(error: Error)
    func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?)
    func showSimpleAlert(title: String, subtitle: String?)
}

extension GlobalRouter {
    
    /// Dismiss this screen and all screens in front of it.
    func dismissScreen() {
        router.dismissScreen()
    }

    /// Dismiss the closest .sheet or .fullScreenCover to this screen.
    func dismissEnvironment() {
        router.dismissEnvironment()
    }
    
    func showAlert(error: Error) {
        if error.isOfflineError {
            showOfflineAlert()
            return
        }
        router.showAlert(.alert, title: String(localized: "Error"), subtitle: error.localizedDescription, buttons: { })
    }

    func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
        router.showAlert(
            .alert,
            title: title,
            subtitle: subtitle,
            buttons: {
                buttons?()
            }
        )
    }

    func showSimpleAlert(title: String, subtitle: String?) {
        router.showAlert(.alert, title: title, subtitle: subtitle, buttons: { })
    }

    /// Starting a workout while one is running asks first. Two screens can start one, so the
    /// prompt lives here rather than in each presenter.
    func showActiveWorkoutAlert(onResume: @escaping @Sendable () -> Void, onReplace: @escaping @Sendable () -> Void) {
        showAlert(
            title: String(localized: "Active Workout"),
            subtitle: String(localized: "You already have an active workout."),
            buttons: {
                AnyView(VStack {
                    Button("Resume", action: onResume)
                    Button("Discard & Start New", role: .destructive, action: onReplace)
                    Button("Cancel", role: .cancel) { }
                })
            }
        )
    }

    func showConfirmationDialog(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
        router.showAlert(
            .confirmationDialog,
            title: title,
            subtitle: subtitle,
            buttons: {
                buttons?()
            }
        )
    }
    
    func showLoadingModal() {
        router.showModal(
            transition: .opacity,
            backgroundColor: .black.opacity(0.3),
            destination: {
                ProgressView()
                    .tint(.white)
            }
        )
    }
    
    func dismissModal() {
        router.dismissModal()
    }
}
