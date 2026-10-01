//
//  GlobalRouter.swift
//  Compound
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
    func showAlert(title: String, error: Error)
    func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?)
    func showSimpleAlert(title: String, subtitle: String?)
    func showConfirmationDialog(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?)
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
    
    /// Prefer `showAlert(title:error:)` with a title that says what failed ("Unable to Save
    /// Weight"). This one is for callers that have not been given one yet.
    func showAlert(error: Error) {
        showAlert(title: String(localized: "Something Went Wrong"), error: error)
    }

    /// The title says what failed. The message is the error's own words only when the app wrote
    /// them; a Firebase or URL error's description is developer text, so those get "Please try again."
    func showAlert(title: String, error: Error) {
        if error.isOfflineError {
            showOfflineAlert()
            return
        }
        router.showAlert(.alert, title: title, subtitle: error.userFacingMessage, buttons: { })
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
    /// prompt lives here rather than in each presenter. A choice that follows the person's own
    /// action, so an action sheet rather than an alert.
    func showActiveWorkoutAlert(onResume: @escaping @Sendable () -> Void, onReplace: @escaping @Sendable () -> Void) {
        showConfirmationDialog(
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

    /// Starting a meal while a draft is open asks first. Search, the Dashboard and Energy Balance
    /// can all start one, so the prompt lives here rather than in each presenter.
    func showDraftMealDialog(onContinue: @escaping @Sendable () -> Void, onStartNew: @escaping @Sendable () -> Void) {
        showConfirmationDialog(
            title: String(localized: "Draft Meal"),
            subtitle: String(localized: "You already have a draft meal."),
            buttons: {
                AnyView(VStack {
                    Button("Continue Editing", action: onContinue)
                    Button("Start New Meal", role: .destructive, action: onStartNew)
                    Button("Cancel", role: .cancel) { }
                })
            }
        )
    }

    /// Closing a form that holds typed input asks first. A screen calls this from its close button
    /// when it has unsaved changes, and sets `.interactiveDismissDisabled` from the same flag so the
    /// swipe cannot go past it.
    func showDiscardChangesDialog(onDiscard: @escaping @Sendable () -> Void) {
        showConfirmationDialog(
            title: String(localized: "Discard Changes?"),
            subtitle: nil,
            buttons: {
                AnyView(VStack {
                    Button("Discard Changes", role: .destructive, action: onDiscard)
                    Button("Keep Editing", role: .cancel) { }
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
            // It covers a save or a sign-in. A tap outside used to dismiss it and hand the screen
            // back while the work was still running.
            dismissOnBackgroundTap: false,
            destination: {
                // On glass rather than a bare white spinner, which vanished over a light screen.
                ProgressView()
                    .controlSize(.large)
                    .padding(Spacing.xl)
                    .glassEffect(.regular, in: .rect(cornerRadius: Radius.l, style: .continuous))
                    .accessibilityLabel(Text("Loading"))
                    .accessibilityAddTraits(.isModal)
            }
        )
    }
    
    func dismissModal() {
        router.dismissModal()
    }
}

extension Error {
    /// What an error alert says under its title. An error the app defines with its own
    /// `errorDescription` says that; anything from a framework (Firebase, URLSession, Cocoa) says
    /// "Please try again.", because its description is written for developers.
    var userFacingMessage: String {
        if !(type(of: self) is NSError.Type), !(self is CustomNSError),
           let description = (self as? LocalizedError)?.errorDescription, !description.isEmpty {
            return description
        }
        return String(localized: "Please try again.")
    }
}
