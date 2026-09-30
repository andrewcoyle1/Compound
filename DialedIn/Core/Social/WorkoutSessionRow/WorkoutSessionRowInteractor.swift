//
//  WorkoutSessionRowInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/02/2026.
//

@MainActor
protocol WorkoutSessionRowInteractor: ReportInteractor {
    var currentUser: UserModel? { get }
    func workoutSessions(authoredBy authorId: String) -> [WorkoutSessionModel]
    func likeSession(sessionId: String, authorId: String, userId: String) async throws
    func unlikeSession(sessionId: String, authorId: String, userId: String) async throws
    var allExercises: [ExerciseModel] { get }
    var allWorkoutTemplates: [WorkoutTemplateModel] { get }
    func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws
}

extension CoreInteractor: WorkoutSessionRowInteractor { }
