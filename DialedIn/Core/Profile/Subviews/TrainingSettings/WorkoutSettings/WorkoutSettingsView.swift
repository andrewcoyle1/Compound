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
            displaySection
            warmUpSection
            otherSection
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
            CustomLabelButtonView(
                symbolName: "timer",
                title: String(localized: "Rest Timer"),
                subtitle: String(localized: "Configure rest timer settings")) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .padding()
                        .anyButton(.press) {
                            presenter.onRestTimerSettingsPressed()
                        }
                    .accessibilityLabel("Rest Timer")
                }
            CustomLabelButtonView(
                symbolName: "wand.and.stars",
                title: String(localized: "Smart Progression"),
                subtitle: String(localized: "Configure smart progression settings")) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .padding()
                        .anyButton(.press) {
                            presenter.onSmartProgressionSettingsPressed()
                        }
                    .accessibilityLabel("Smart Progression")
                }
            CustomLabelButtonView(
                symbolName: "arrow.trianglehead.counterclockwise",
                title: String(localized: "Previous Reference"),
                subtitle: String(localized: "Any Workout")) {
                    Text("Edit")
                        .padding(.horizontal, 8)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2), in: .capsule)
                        .anyButton(.press) {
                            presenter.onPreviousReferenceSettingsPressed()
                        }
                }
            CustomToggleView(
                symbolName: "arrow.uturn.forward",
                title: String(localized: "Propagate Changes"),
                subtitle: String(localized: "Weight and rep edits will propagate to all sets with the same weight and reps"),
                bool: $presenter.propagateChanges
            )
            CustomToggleView(
                symbolName: "heart.fill",
                title: String(localized: "Effort (RPE)"),
                subtitle: String(localized: "Log how hard each set was, from RPE 6 to 10, on the reps keyboard"),
                bool: $presenter.rirTracking
            )
            CustomToggleView(
                symbolName: "arrow.trianglehead.2.clockwise",
                title: String(localized: "Superset Auto-Scroll"),
                subtitle: String(localized: "Scroll automatically between superset exercises after set completion"),
                bool: $presenter.supersetAutoScroll
            )
            CustomToggleView(
                symbolName: "arrow.right.to.line.compact",
                title: String(localized: "Exercise Auto-Next"),
                subtitle: String(localized: "Scroll next automatically when an exercise is completed"),
                bool: $presenter.exerciseAutoNext
            )

        } header: {
            Text("General")
        }

    }
    
    private var displaySection: some View {
        Section {
            CustomToggleView(
                symbolName: "sun.max",
                title: String(localized: "Keep Alive"),
                subtitle: String(localized: "Keep your phone alive during active workout sessions"),
                bool: $presenter.keepAlive
            )
            CustomToggleView(
                symbolName: "timer",
                title: String(localized: "Workout Timer"),
                subtitle: String(localized: "Show elapsed time during workout sessions"),
                bool: $presenter.showWorkoutTimer
            )
            CustomToggleView(
                symbolName: "scalemass",
                title: String(localized: "Bodyweight Contribution"),
                subtitle: String(localized: "Display scale weight and body weight contribution during workout sessions"),
                bool: $presenter.showBodyweightContribution
            )
            
        } header: {
            Text("Display")
        }
    }
    private var warmUpSection: some View {
        Section {
            CustomToggleView(
                symbolName: "figure.yoga",
                title: String(localized: "Add Smart Warm-Ups"),
                subtitle: String(localized: "Warm-Ups will be automatically added to exercises in your workout depending on how fresh your muscles are and how heavy the weight is"),
                bool: $presenter.addSmartWarmUps
            )

        } header: {
            Text("Warm-Up")
        }

    }

    private var otherSection: some View {
        
        Section {
            CustomLabelButtonView(
                symbolName: "list.star",
                title: String(localized: "Exercise Assessment"),
                subtitle: String(localized: "A questionnaire about your experience with foundational movements that determines access to advanced exercises")) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .foregroundStyle(.secondary)
                        .padding()
                        .anyButton(.press) {
                            presenter.onExerciseAssessmentPressed()
                        }
                    .accessibilityLabel("Exercise Assessment")
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
