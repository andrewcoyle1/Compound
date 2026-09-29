//
//  WorkoutSessionRowRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/02/2026.
//

@MainActor
protocol WorkoutSessionRowRouter: ShareSheetRouter {
    func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate)
    func showSocialProfileView(delegate: SocialProfileDelegate)
    func showCommentsView(delegate: CommentsDelegate)
    func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate)
    func showShareToFollowerView(delegate: ShareToFollowerDelegate)
}

extension CoreRouter: WorkoutSessionRowRouter { }
