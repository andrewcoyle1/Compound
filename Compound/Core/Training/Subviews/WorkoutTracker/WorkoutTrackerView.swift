//
//  WorkoutTrackerView.swift
//  Compound
//
//  Created by Andrew Coyle on 23/09/2025.
//

import SwiftUI
import HealthKit
import Combine

struct WorkoutTrackerView<ExerciseTracker: View>: View {

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State var presenter: WorkoutTrackerPresenter
    /// The set keyboard has its own Done, which logs the set, so the log button steps aside rather
    /// than riding up over the row being edited.
    @State var isKeyboardVisible = false

    @ViewBuilder var exerciseTrackerView: (ExerciseTrackerDelegate, ((Int) -> Void)?) -> ExerciseTracker
    
    var body: some View {
        List {
            if presenter.workoutSession.exercises.isEmpty {
                ContentUnavailableView {
                    Text("No Exercises")
                } description: {
                    Text("Please add some exercises to get started.")
                }
                .removeListRowFormatting()
            } else {
                currentExerciseSection
                upNextSection
                completedSection
            }
            addExerciseSection
        }
        .navigationTitle(presenter.workoutSession.name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        // The rest timer and the column headings are a line of text each, not a 44 pt row. Every
        // control in the table carries its own 44 pt hit area.
        .environment(\.defaultMinListRowHeight, Spacing.xl)
        .environment(\.editMode, $presenter.editMode)
        .onChange(of: presenter.pendingSelectedTemplates) { _, newValue in
            guard !newValue.isEmpty else { return }
            presenter.addSelectedExercises()
        }
        .toolbar {
            toolbarContent
        }
        .safeAreaBar(edge: .top) {
            WorkoutProgressHeader(presenter: presenter)
        }
        // Hard, so a scrolled set table never shows through the progress text at large sizes.
        .scrollEdgeEffectStyle(.hard, for: .top)
        .bottomCTA {
            primaryCTA
        }
        .reducedMotionAnimation(.emphasis, value: presenter.canQuickFinish)
        .reducedMotionAnimation(.standard, value: presenter.runningRestEnd == nil)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onChange(of: presenter.canQuickFinish) { _, isAvailable in
            presenter.onQuickFinishAvailabilityChanged(isAvailable)
        }
        .task {
            await presenter.observeRestCompletions()
        }
        .task {
            await presenter.onAppear()
        }
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            presenter.onScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
    }
}

extension CoreBuilder {
    func workoutTrackerView(router: AnyRouter) throws -> some View {
        WorkoutTrackerView(
            presenter: try WorkoutTrackerPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            exerciseTrackerView: { delegate, onStartRest in
                self.exerciseTrackerView(
                    router: router,
                    delegate: delegate,
                    onStartRest: onStartRest
                )
            }
        )
    }
}

extension CoreRouter {
    /// The screen id the tracker is presented under, so a second request can see it is up.
    static let workoutTrackerScreenId = "workout-tracker"

    /// Pushed on the tracker's own stack when the workout is finished, so the cover ends on what
    /// was done rather than closing and opening a second modal. The one-time Strava offer goes
    /// from the summary's router so the dialog lands over it.
    func showWorkoutSummary(session: WorkoutSessionModel) {
        router.showScreen(.push) { router in
            builder.workoutSessionDetailView(
                router: router,
                delegate: WorkoutSessionDetailDelegate(workoutSession: session, isWorkoutSummary: true)
            )
            .task {
                await CoreRouter(router: router, builder: builder).offerStravaIfFirstWorkout(session)
            }
        }
    }

    /// Every way into the tracker comes through here: the Live Activity, the widget, Training,
    /// Search. A tap on the Live Activity while the tracker is already open must not stack a
    /// second tracker on it, and with no workout under way the builder throws, which used to
    /// present an empty cover with no way out.
    func showWorkoutTrackerView() {
        guard !router.activeScreens.allScreens.contains(where: { $0.id == Self.workoutTrackerScreenId }) else { return }
        guard builder.interactor.activeSession != nil else {
            showSimpleAlert(
                title: String(localized: "No Workout in Progress"),
                subtitle: String(localized: "Start a workout from Training.")
            )
            return
        }
        router.showScreen(.fullScreenCover, id: Self.workoutTrackerScreenId) { router in
            try? builder.workoutTrackerView(router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        try? builder.workoutTrackerView(router: router)
    }
}
