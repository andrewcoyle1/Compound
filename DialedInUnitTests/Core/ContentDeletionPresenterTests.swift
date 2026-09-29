//
//  ContentDeletionPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 24/09/2026.
//
//  The author's delete on the three detail screens that had none: a custom exercise, recipe and
//  food. Each asks first, deletes by the right id and leaves, or says so and stays when the delete
//  fails. Only the author is offered the delete at all.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

private enum DeletionTestError: Error { case failed }

/// Records the alerts on the class declaring the conformance, or the protocol's default runs and
/// the alert escapes to the real router unseen. `showDevSettingsView()` is unguarded because the
/// test target builds without `-DDEV`.
@MainActor
private class AlertRecordingRouter: GlobalRouter {
    let router: AnyRouter = TestRouting.anyRouter
    private(set) var alertTitles: [String] = []
    private(set) var simpleAlertTitles: [String] = []

    func showAlert(error: Error) { alertTitles.append("Error") }
    func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
    func showSimpleAlert(title: String, subtitle: String?) { simpleAlertTitles.append(title) }
    func showDevSettingsView() { }
}

// MARK: - Exercise

@MainActor
struct ExerciseModelDetailDeletionTests {

    private final class Interactor: ExerciseModelDetailInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var workoutSessions: [WorkoutSessionModel] = []
        var deleteError: Error?
        private(set) var deletedIds: [String] = []

        func getPreference(templateId: String) -> ExerciseUnitPreference {
            ExerciseUnitPreference(exerciseModelId: templateId)
        }

        func deleteExerciseModel(exerciseId: String) async throws {
            if let deleteError { throw deleteError }
            deletedIds.append(exerciseId)
        }
    }

    private final class Router: AlertRecordingRouter, ExerciseModelDetailRouter { }

    private func exercise(authorId: String = "user-1", isSystem: Bool = false) -> ExerciseModel {
        ExerciseModel(
            id: "curl",
            authorId: authorId,
            name: "Curl",
            trackableMetrics: [.weight, .reps],
            type: nil,
            laterality: nil,
            muscleGroups: [:],
            isBodyweight: false,
            rangeOfMotion: 1,
            stability: 1,
            bodyWeightContribution: 0,
            alternateNames: [],
            isSystemExercise: isSystem
        )
    }

    @Test("Test Only The Authors Own Custom Exercise Can Be Deleted")
    func testOnlyTheAuthorsOwnCustomExerciseCanBeDeleted() {
        let presenter = ExerciseModelDetailPresenter(interactor: Interactor(), router: Router())

        #expect(presenter.canDelete(exercise: exercise()))
        #expect(!presenter.canDelete(exercise: exercise(authorId: "someone-else")))
        #expect(!presenter.canDelete(exercise: exercise(isSystem: true)))
    }

    @Test("Test Delete Asks First")
    func testDeleteAsksFirst() {
        let interactor = Interactor()
        let router = Router()
        let presenter = ExerciseModelDetailPresenter(interactor: interactor, router: router)

        presenter.showDeleteConfirmation(exercise: exercise())

        #expect(router.alertTitles == ["Delete Exercise"])
        #expect(interactor.deletedIds.isEmpty)
    }

    @Test("Test Confirmed Delete Removes The Exercise Then Leaves")
    func testConfirmedDeleteRemovesTheExerciseThenLeaves() async {
        let interactor = Interactor()
        let presenter = ExerciseModelDetailPresenter(interactor: interactor, router: Router())
        var dismissed = false

        await presenter.deleteExercise(exercise(), onDismiss: { dismissed = true })

        #expect(interactor.deletedIds == ["curl"])
        #expect(dismissed)
    }

    @Test("Test A Failed Delete Says So And Stays")
    func testAFailedDeleteSaysSoAndStays() async {
        let interactor = Interactor()
        interactor.deleteError = DeletionTestError.failed
        let router = Router()
        let presenter = ExerciseModelDetailPresenter(interactor: interactor, router: router)
        var dismissed = false

        await presenter.deleteExercise(exercise(), onDismiss: { dismissed = true })

        #expect(!dismissed)
        #expect(!presenter.isDeleting)
        #expect(router.simpleAlertTitles == ["Failed to delete exercise"])
    }
}

// MARK: - Recipe

@MainActor
struct RecipeDetailDeletionTests {

    private final class Interactor: RecipeDetailInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var deleteError: Error?
        private(set) var deletedIds: [String] = []

        func isFavouriteRecipe(id: String) -> Bool { false }
        func setFavouriteRecipe(id: String, isFavourite: Bool) async throws { }

        func deleteRecipeTemplate(id: String) async throws {
            if let deleteError { throw deleteError }
            deletedIds.append(id)
        }
    }

    private final class Router: AlertRecordingRouter, RecipeDetailRouter {
        func showStartRecipeView(delegate: RecipeStartDelegate) { }
    }

    private func recipe(authorId: String = "user-1") -> RecipeTemplateModel {
        let date = Date(timeIntervalSince1970: 1_000_000)
        return RecipeTemplateModel(id: "chilli", authorId: authorId, name: "Chilli", dateCreated: date, dateModified: date)
    }

    @Test("Test Only The Authors Recipe Can Be Deleted")
    func testOnlyTheAuthorsRecipeCanBeDeleted() {
        let presenter = RecipeDetailPresenter(interactor: Interactor(), router: Router())

        #expect(presenter.canDelete(recipe: recipe()))
        #expect(!presenter.canDelete(recipe: recipe(authorId: "someone-else")))
    }

    @Test("Test Delete Asks First")
    func testDeleteAsksFirst() {
        let interactor = Interactor()
        let router = Router()
        let presenter = RecipeDetailPresenter(interactor: interactor, router: router)

        presenter.showDeleteConfirmation(recipe: recipe())

        #expect(router.alertTitles == ["Delete Recipe"])
        #expect(interactor.deletedIds.isEmpty)
    }

    @Test("Test Confirmed Delete Removes The Recipe Then Leaves")
    func testConfirmedDeleteRemovesTheRecipeThenLeaves() async {
        let interactor = Interactor()
        let presenter = RecipeDetailPresenter(interactor: interactor, router: Router())
        var dismissed = false

        await presenter.deleteRecipe(recipe(), onDismiss: { dismissed = true })

        #expect(interactor.deletedIds == ["chilli"])
        #expect(dismissed)
    }

    @Test("Test A Failed Delete Says So And Stays")
    func testAFailedDeleteSaysSoAndStays() async {
        let interactor = Interactor()
        interactor.deleteError = DeletionTestError.failed
        let router = Router()
        let presenter = RecipeDetailPresenter(interactor: interactor, router: router)
        var dismissed = false

        await presenter.deleteRecipe(recipe(), onDismiss: { dismissed = true })

        #expect(!dismissed)
        #expect(!presenter.isDeleting)
        #expect(router.simpleAlertTitles == ["Failed to delete recipe"])
    }
}

// MARK: - Food

@MainActor
struct FoodDetailDeletionTests {

    private final class Interactor: SpyGlobalInteractor, FoodDetailInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var deleteError: Error?
        private(set) var deletedIds: [String] = []

        func isFavouriteFood(id: String) -> Bool { false }
        func setFavouriteFood(id: String, isFavourite: Bool) async throws { }

        func deleteFood(ingredientId: String) async throws {
            if let deleteError { throw deleteError }
            deletedIds.append(ingredientId)
        }
    }

    private final class Router: AlertRecordingRouter, FoodDetailRouter { }

    private func food(authorId: String? = "user-1") -> FoodModel {
        FoodModel(ingredientId: "oats", authorId: authorId, name: "Oats")
    }

    @Test("Test Only The Authors Food Can Be Deleted")
    func testOnlyTheAuthorsFoodCanBeDeleted() {
        let presenter = FoodDetailPresenter(interactor: Interactor(), router: Router())

        #expect(presenter.canDelete(food: food()))
        #expect(!presenter.canDelete(food: food(authorId: "someone-else")))
        #expect(!presenter.canDelete(food: food(authorId: nil)))
    }

    @Test("Test Delete Asks First")
    func testDeleteAsksFirst() {
        let interactor = Interactor()
        let router = Router()
        let presenter = FoodDetailPresenter(interactor: interactor, router: router)

        presenter.showDeleteConfirmation(food: food())

        #expect(router.alertTitles == ["Delete Food"])
        #expect(interactor.deletedIds.isEmpty)
    }

    @Test("Test Confirmed Delete Removes The Food Then Leaves")
    func testConfirmedDeleteRemovesTheFoodThenLeaves() async {
        let interactor = Interactor()
        let presenter = FoodDetailPresenter(interactor: interactor, router: Router())
        var dismissed = false

        await presenter.deleteFood(food(), onDismiss: { dismissed = true })

        #expect(interactor.deletedIds == ["oats"])
        #expect(dismissed)
    }

    @Test("Test A Failed Delete Says So And Stays")
    func testAFailedDeleteSaysSoAndStays() async {
        let interactor = Interactor()
        interactor.deleteError = DeletionTestError.failed
        let router = Router()
        let presenter = FoodDetailPresenter(interactor: interactor, router: router)
        var dismissed = false

        await presenter.deleteFood(food(), onDismiss: { dismissed = true })

        #expect(!dismissed)
        #expect(!presenter.isDeleting)
        #expect(router.simpleAlertTitles == ["Failed to delete food"])
    }
}
