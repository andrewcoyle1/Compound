//
//  WeightGoalFlowRouter.swift
//  Compound
//
//  The way into setting or changing the weight goal, from Settings and Goal Progress alike.
//

import SwiftUI

@MainActor
protocol WeightGoalFlowRouter: GlobalRouter {
    /// Sets a new goal, or edits `editing` when given.
    func showWeightGoalFlow(editing: WeightGoal?)
}

/// With a goal running, the choice is to adjust it (where it started stays) or to start a new one
/// from today's weight. The presenter passes what each choice does, so the buttons capture it
/// rather than the router.
@MainActor
enum WeightGoalChoices {

    static func show(
        on router: any GlobalRouter,
        onEdit: @escaping @MainActor @Sendable () -> Void,
        onStartNew: @escaping @MainActor @Sendable () -> Void
    ) {
        router.showConfirmationDialog(
            title: String(localized: "Weight Goal"),
            subtitle: String(localized: "Edit your target and pace, or start a new goal from today's weight."),
            buttons: {
                AnyView(VStack {
                    Button("Edit Goal") { onEdit() }
                    Button("Start a New Goal") { onStartNew() }
                    Button("Cancel", role: .cancel) { }
                })
            }
        )
    }
}

extension CoreRouter: WeightGoalFlowRouter { }
