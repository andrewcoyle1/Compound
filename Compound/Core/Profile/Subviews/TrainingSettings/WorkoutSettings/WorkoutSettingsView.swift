import SwiftUI

struct WorkoutSettingsDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct WorkoutSettingsView: View {
    
    @State var presenter: WorkoutSettingsPresenter
    let delegate: WorkoutSettingsDelegate
    
    var body: some View {
        List {
            generalSection
            previousReferenceSection
            displaySection
            warmUpSection
            
            // Pending: Exercise Assessment is hidden: its screen describes test lifts that nothing runs and nothing unlocks. Put `otherSection` back here once the assessment and the exercises it unlocks exist.
        }
        .navigationTitle("Workout Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }
    
    private var generalSection: some View {
        Section {
            ListRowButton(
                title: String(localized: "Rest Timer"),
                subtitle: String(localized: "Configure rest timer settings"),
                systemImage: Symbol.rest
            ) {
                presenter.onRestTimerSettingsPressed()
            }
            ListRowButton(
                title: String(localized: "Smart Progression"),
                subtitle: String(localized: "Configure smart progression settings"),
                systemImage: "wand.and.stars"
            ) {
                presenter.onSmartProgressionSettingsPressed()
            }
            ListRowToggle(
                title: String(localized: "Propagate Changes"),
                subtitle: String(localized: "Weight and rep edits will propagate to all sets with the same weight and reps"),
                systemImage: "arrow.uturn.forward",
                isOn: $presenter.propagateChanges
            )
            ListRowToggle(
                title: String(localized: "Effort (RPE)"),
                subtitle: String(localized: "Log how hard each set was, from RPE 6 to 10, on the reps keyboard"),
                systemImage: "heart.fill",
                isOn: $presenter.rirTracking
            )
            ListRowToggle(
                title: String(localized: "Superset Auto-Scroll"),
                subtitle: String(localized: "Scroll automatically between superset exercises after set completion"),
                systemImage: "arrow.trianglehead.2.clockwise",
                isOn: $presenter.supersetAutoScroll
            )
            Picker(selection: $presenter.supersetTransitionRestSeconds) {
                ForEach(presenter.supersetTransitionRestOptions, id: \.self) { seconds in
                    Text(presenter.supersetTransitionRestTitle(seconds)).tag(seconds)
                }
            } label: {
                Label("Rest between superset partners", systemImage: Symbol.rest)
            }
            ListRowToggle(
                title: String(localized: "Exercise Auto-Next"),
                subtitle: String(localized: "Move to the next exercise when its rest ends"),
                systemImage: "arrow.right.to.line.compact",
                isOn: $presenter.exerciseAutoNext
            )

        } header: {
            Text("General")
        }

    }
    
    /// A checkmark list rather than a `Picker`, so each option can carry the explanation the
    /// option enum already defines as its `subtitle`.
    private var previousReferenceSection: some View {
        Section {
            ForEach(presenter.previousWorkoutReferenceOptions) { option in
                SelectableRow(
                    title: option.title,
                    subtitle: option.subtitle,
                    isSelected: presenter.previousWorkoutReference == option
                ) {
                    presenter.previousWorkoutReference = option
                }
            }
        } header: {
            Text("Previous Reference")
        } footer: {
            Text("Applies to the previous values shown beside each set while you train.")
        }
    }

    private var displaySection: some View {
        Section {
            ListRowToggle(
                title: String(localized: "Keep Screen On"),
                subtitle: String(localized: "Stop the screen locking during a workout"),
                systemImage: "sun.max",
                isOn: $presenter.keepAlive
            )
            ListRowToggle(
                title: String(localized: "Workout Timer"),
                subtitle: String(localized: "Show elapsed time during workout sessions"),
                systemImage: Symbol.duration,
                isOn: $presenter.showWorkoutTimer
            )
            ListRowToggle(
                title: String(localized: "Bodyweight Contribution"),
                subtitle: String(localized: "Display scale weight and body weight contribution during workout sessions"),
                systemImage: Symbol.scaleWeight,
                isOn: $presenter.showBodyweightContribution
            )
            ListRowToggle(
                title: String(localized: "Show on Lock Screen"),
                subtitle: String(localized: "Follow each workout on the Lock Screen and in the Dynamic Island"),
                systemImage: "platter.filled.bottom.iphone",
                isOn: $presenter.showOnLockScreen
            )

        } header: {
            Text("Display")
        }
    }
    private var warmUpSection: some View {
        Section {
            ListRowToggle(
                title: String(localized: "Add Smart Warm-Ups"),
                subtitle: String(localized: "Add warm-up sets based on the weight and how fresh you are"),
                systemImage: "figure.yoga",
                isOn: $presenter.addSmartWarmUps
            )

        } header: {
            Text("Warm-Up")
        }

    }

    private var otherSection: some View {
        
        Section {
            ListRowButton(
                title: String(localized: "Exercise Assessment"),
                subtitle: String(localized: "Unlock advanced exercises"),
                systemImage: "list.star"
            ) {
                presenter.onExerciseAssessmentPressed()
            }

        } header: {
            Text("Other")
        }

    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = WorkoutSettingsDelegate()
    
    return RouterView { router in
        builder.workoutSettingsView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func workoutSettingsView(router: AnyRouter, delegate: WorkoutSettingsDelegate) -> some View {
        WorkoutSettingsView(
            presenter: WorkoutSettingsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showWorkoutSettingsView(delegate: WorkoutSettingsDelegate) {
        router.showScreen(.push) { router in
            builder.workoutSettingsView(router: router, delegate: delegate)
        }
    }
    
}
