//
//  WorkoutSessionRowStatsTests.swift
//  CompoundUnitTests
//
//  The feed card's numbers: volume, duration and each exercise's sets line, all through `Format`.
//

import Testing
import SwiftUI
@testable import Compound

@MainActor
struct WorkoutSessionRowStatsTests {

    private final class Interactor: SpyGlobalInteractor, WorkoutSessionRowInteractor {
        var currentUser: UserModel? = UserModel(userId: "me")
        var allExercises: [ExerciseModel] = []
        var allWorkoutTemplates: [WorkoutTemplateModel] = []
        func workoutSessions(authoredBy authorId: String) -> [WorkoutSessionModel] { [] }
        func likeSession(sessionId: String, authorId: String, userId: String) async throws { }
        func unlikeSession(sessionId: String, authorId: String, userId: String) async throws { }
        func report(contentType: ReportContentType, contentId: String, authorUserId: String?, reason: ReportReason, notes: String?) async throws { }
        func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws { }
    }

    private final class Router: WorkoutSessionRowRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) { }
        func showSocialProfileView(delegate: SocialProfileDelegate) { }
        func showCommentsView(delegate: CommentsDelegate) { }
        func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate) { }
        func showShareToFollowerView(delegate: ShareToFollowerDelegate) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(_ index: Int, reps: Int? = nil, kilograms: Double? = nil, seconds: Int? = nil, meters: Double? = nil, warmup: Bool = false) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "s\(index)", authorId: "me", index: index, reps: reps, weightKg: kilograms, durationSec: seconds,
            distanceMeters: meters, isWarmup: warmup, completedAt: start, dateCreated: start
        )
    }

    private func exercise(_ mode: TrackingMode, _ sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
        WorkoutExerciseModel(id: "e-\(mode)", authorId: "me", templateId: "t", name: "Lift", trackingMode: mode, index: 1, sets: sets)
    }

    private func row(_ exercises: [WorkoutExerciseModel], minutes: Double? = 65) -> WorkoutSessionRowPresenter {
        let session = WorkoutSessionModel(
            id: "session", authorId: "me", name: "Push", dateCreated: start,
            endedAt: minutes.map { start.addingTimeInterval($0 * 60) }, exercises: exercises
        )
        return WorkoutSessionRowPresenter(interactor: Interactor(), router: Router(), delegate: WorkoutSessionRowDelegate(session: session, author: UserModel(userId: "me")))
    }

    @Test("Test Volume Counts Working Sets Only And Switches To Tonnes")
    func testVolumeCountsWorkingSetsOnlyAndSwitchesToTonnes() {
        let light = row([exercise(.weightReps, [set(1, reps: 10, kilograms: 20, warmup: true), set(2, reps: 10, kilograms: 50)])])
        #expect(light.volumeText == Format.weight(kg: 500, unit: WeightUnitPreference.kilograms))
        #expect(light.workingSetCount == 1)

        let heavy = row([exercise(.weightReps, [set(1, reps: 5, kilograms: 100), set(2, reps: 5, kilograms: 150)])])
        #expect(heavy.volumeText == "\(1.25.formatted(.number.precision(.fractionLength(1)))) t")

        #expect(row([exercise(.repsOnly, [set(1, reps: 10)])]).volumeText == nil)
    }

    @Test("Test Duration Goes Through Format And Is Absent While Running")
    func testDurationGoesThroughFormatAndIsAbsentWhileRunning() {
        #expect(row([], minutes: 65).durationText == Format.duration(65 * 60))
        #expect(row([], minutes: nil).durationText == nil)
    }

    @Test("Test Each Tracking Mode Describes Its First Working Set")
    func testEachTrackingModeDescribesItsFirstWorkingSet() {
        let presenter = row([])
        #expect(presenter.setsDescription(for: exercise(.weightReps, [set(1, reps: 8, kilograms: 82.5), set(2, reps: 8, kilograms: 82.5)]))
                == "2 × 8 @ \(Format.weight(kg: 82.5, unit: WeightUnitPreference.kilograms))")
        #expect(presenter.setsDescription(for: exercise(.repsOnly, [set(1, reps: 12)])) == "1 × 12")
        #expect(presenter.setsDescription(for: exercise(.timeOnly, [set(1, seconds: 45)])) == "1 × \(Format.duration(45))")
        #expect(presenter.setsDescription(for: exercise(.distanceTime, [set(1, meters: 5000)]))
                == "1 × \(Format.distance(meters: 5000, unit: .kilometers))")
        #expect(presenter.setsDescription(for: exercise(.timeOnly, [set(1, reps: 3)])) == "1 set")
    }
}
