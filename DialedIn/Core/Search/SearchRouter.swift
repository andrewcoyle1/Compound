//
//  SearchRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/01/2026.
//

import SwiftUI

@MainActor
protocol SearchRouter: GlobalRouter, InviteAcceptRouter {
    func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID)
    func showExerciseDetailView(templateId: String, name: String, delegate: ExerciseDetailDelegate, themeColor: Color?)
    func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate)
    func showRecipeDetailView(delegate: RecipeDetailDelegate)
    func showFoodDetailView(delegate: FoodDetailDelegate)
    func showSocialProfileView(delegate: SocialProfileDelegate)
    func showRecipesView()
    func showAddMealView(delegate: AddMealDelegate)
    func showCreateExerciseView()
    func showCreateWorkoutView(delegate: CreateWorkoutDelegate)
    func showCreateFoodView(delegate: CreateFoodDelegate)
    func showCreateRecipeView()
    func showExerciseListBuilderView(delegate: ExerciseListBuilderDelegate)
    func showWorkoutTrackerView()
    func showLogWeightView()
    func showBodyMetricsView(delegate: BodyMetricsDelegate)
    func showShortcutsView(delegate: ShortcutsDelegate)
}

extension CoreRouter: SearchRouter { }
