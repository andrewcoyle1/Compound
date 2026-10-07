//
//  ExerciseTrackerPlanTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 07/10/2026.
//

import Testing
import Foundation
@testable import Compound

/// What the plan puts on the exercise card: its notes under the name, and Watch in the menu only
/// for a link the browser can open.
@MainActor
struct ExerciseTrackerPlanTests {

    private final class Interactor: SpyGlobalInteractor, ExerciseTrackerInteractor {
        var allExercises: [ExerciseModel] = []
        func exerciseNote(for exerciseId: String) -> String? { nil }
    }

    private final class Router: ExerciseTrackerRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showWorkoutNotesView(delegate: WorkoutNotesDelegate) { }
    }

    private var presenter: ExerciseTrackerPresenter {
        ExerciseTrackerPresenter(interactor: Interactor(), router: Router())
    }

    private func exercise(planNotes: String? = nil, linkURL: String? = nil) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "e1", authorId: "author-1", templateId: "template-1", name: "Bench Press",
            trackingMode: .weightReps, index: 1, sets: [], planNotes: planNotes, linkURL: linkURL
        )
    }

    @Test("Test Watch Shows For A Web Link", arguments: [
        "https://example.com/bench",
        "http://example.com/bench?t=30",
        "  HTTPS://Example.com/bench  "
    ])
    func testWatchShowsForAWebLink(link: String) {
        #expect(presenter.watchURL(for: exercise(linkURL: link)) != nil)
    }

    @Test("Test Watch Is Hidden For Anything Else", arguments: [
        nil, "", "   ", "not a link", "example.com/bench", "ftp://example.com/bench",
        "javascript:alert(1)", "mailto:coach@example.com", "https://"
    ] as [String?])
    func testWatchIsHiddenForAnythingElse(link: String?) {
        #expect(presenter.watchURL(for: exercise(linkURL: link)) == nil)
    }

    @Test("Test Plan Notes Are Trimmed And Blank Shows Nothing")
    func testPlanNotesAreTrimmedAndBlankShowsNothing() {
        #expect(presenter.planNotes(for: exercise(planNotes: "  Pause at the chest \n")) == "Pause at the chest")
        #expect(presenter.planNotes(for: exercise(planNotes: " \n")) == nil)
        #expect(presenter.planNotes(for: exercise()) == nil)
    }
}
