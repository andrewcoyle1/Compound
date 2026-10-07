//
//  WorkoutTrackerView.swift
//  Compound
//
//  Created by Andrew Coyle on 23/09/2025.
//

import SwiftUI
import HealthKit

struct WorkoutTrackerView<ExerciseTracker: View>: View {

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    /// At regular width Pause, Finish and Notes come out of the menu onto the bar.
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State var presenter: WorkoutTrackerPresenter
    @State private var cardSwapEdge = CardSwapEdge()
    /// VoiceOver's cursor on the bottom button, put back after its action changes the screen
    /// (a11y.md C1). See `WorkoutPrimaryCTA`.
    @AccessibilityFocusState var isPrimaryCTAFocused: Bool

    @ViewBuilder var exerciseTrackerView: (ExerciseTrackerDelegate, ((Int) -> Void)?) -> ExerciseTracker
    
    var body: some View {
        ScrollViewReader { proxy in
            // A real container around the list: the reader alone does not run the list's
            // transition, and the swap below fell back to a plain fade.
            ZStack {
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
                // The next set's row, brought up from under the button or the keypad after a log. A
                // nil anchor scrolls only as far as needed, so a row already on screen stays put.
                .onChange(of: presenter.currentLogSetId) { _, setId in
                    guard let setId else { return }
                    withReducedMotionAnimation(.standard) {
                        proxy.scrollTo(setId, anchor: nil)
                    }
                }
                // With the exercise strip on, a new block is a new list, pushed in from the side of
                // the strip it lies on (a fade under Reduce Motion). Off, the list keeps one identity.
                .id(presenter.cardListId)
                .transition(cardTransition)
            }
            .reducedMotionAnimation(.standard, value: presenter.cardListId)
            // Keeps the swap's edge in step with the block and the order shown; it reads them
            // first itself when a swap runs, so these only catch up afterwards.
            .onChange(of: presenter.cardListId, initial: true) { _, blockId in
                cardSwapEdge.edge(to: blockId, order: presenter.blockOrder)
            }
            .onChange(of: presenter.blockOrder) { _, order in
                cardSwapEdge.edge(to: presenter.cardListId, order: order)
            }
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
        // The strip's bar has no solid fill and takes the automatic effect instead.
        .scrollEdgeEffectStyle(presenter.showsExerciseStrip ? .automatic : .hard, for: .top)
        // Always shown, above the keypad too: its animations are its own, so a log no longer
        // animates the whole list with it.
        .bottomCTA {
            primaryCTA
        }
        // The bottom button is the last element in reading order. A two-finger double tap does
        // what it does from anywhere on the screen, and the scrub gesture minimises, as the
        // chevron does (a11y.md M2).
        .accessibilityAction(.magicTap) {
            presenter.onPrimarySlotPressed()
        }
        .accessibilityAction(.escape) {
            presenter.minimizeSession()
        }
        .onChange(of: presenter.primarySlot) { _, action in
            presenter.onPrimarySlotChanged(action)
        }
        .onChange(of: presenter.runningRestEnd) { oldEnd, newEnd in
            presenter.onRunningRestEndChanged(from: oldEnd, to: newEnd)
        }
        .onChange(of: presenter.canQuickFinish) { _, isAvailable in
            presenter.onQuickFinishAvailabilityChanged(isAvailable)
        }
        // Told to VoiceOver as they happen (a11y.md S1): a log, from here or the Lock Screen, and
        // the card moving on.
        .onChange(of: presenter.latestLogMark) { oldMark, newMark in
            presenter.onLatestLogChanged(from: oldMark, to: newMark)
        }
        .onChange(of: presenter.currentExercise?.id) { oldId, newId in
            presenter.onCurrentExerciseChanged(from: oldId, to: newId)
        }
        .task {
            await presenter.observeRestCompletions()
        }
        .task {
            await presenter.observeRestOverAnnouncements()
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

    private var cardTransition: AnyTransition {
        guard presenter.showsExerciseStrip else { return .identity }
        guard !reduceMotion else { return .opacity }
        let swapEdge = cardSwapEdge
        return AnyTransition(CardPush { [presenter] in
            swapEdge.edge(to: presenter.cardListId, order: presenter.blockOrder)
        })
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
