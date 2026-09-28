//
//  WorkoutListInteractorBuilder.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol WorkoutListInteractorBuilder: GlobalInteractor {
    var currentUser: UserModel? { get }
    var userWorkoutTemplates: [WorkoutTemplateModel] { get }
    var systemWorkoutTemplates: [WorkoutTemplateModel] { get }
    var allWorkoutTemplates: [WorkoutTemplateModel] { get }
}

extension CoreInteractor: WorkoutListInteractorBuilder { }
