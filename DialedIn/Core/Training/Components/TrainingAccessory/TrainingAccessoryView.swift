//
//  TrainingAccessoryView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 17/10/2025.
//

import SwiftUI

struct TrainingAccessoryDelegate {
    var active: WorkoutSessionModel
}

struct TrainingAccessoryView: View {
    
    @State var presenter: TrainingAccessoryPresenter
    
    let delegate: TrainingAccessoryDelegate
    
    var body: some View {
        Button {
            presenter.reopenActiveSession()
        } label: {
            workoutDescriptionSection
                .frame(maxWidth: .infinity)
                .padding()
                .tappableBackground()
        }
        .buttonStyle(.plain)
    }
        
    private var workoutDescriptionSection: some View {
        HStack {
            VStack(alignment: .leading) {
                workoutName
                timeSection(workoutSession: delegate.active)
            }
            Spacer()
            exerciseImagesSection
        }
    }

    private var exerciseImagesSection: some View {
        HStack(spacing: -Spacing.s) {
            if let activeSession = presenter.activeSession {
                ForEach(activeSession.exercises.prefix(5)) { exercise in
                    exerciseCircle(exercise: exercise)
                }
            }
        }
    }

    @ViewBuilder
    private func exerciseCircle(exercise: WorkoutExerciseModel) -> some View {
        let isCompleted = !exercise.sets.isEmpty && exercise.sets.allSatisfy { $0.completedAt != nil }
        ZStack {
            Circle()
                .fill(.canvas)

            ImageLoaderView(
                urlString: exercise.imageName ?? "SplashScreen",
                resizingMode: .fit,
                clipShape: AnyShape(Circle())
            )
            .grayscale(isCompleted ? 1 : 0)

            if isCompleted {
                Circle()
                    .fill(.black.opacity(0.4))
                Image(systemName: "checkmark")
                    .font(.label.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        // Fixed, not scaled: the tab bar accessory has a fixed height and larger circles would clip.
        .frame(width: 38, height: 38)
        .overlay(Circle().stroke(.surface, lineWidth: 2))
        .accessibilityHidden(true)
    }
    
    private var workoutName: some View {
        Text(delegate.active.name)
            .font(.rowDetail)
            .fontWeight(.semibold)
            .lineLimit(1)
    }

    private func timeSection(workoutSession active: WorkoutSessionModel) -> some View {
        Group {
            let now = Date()
            if let restEndTime = presenter.restEndTime,
               now < restEndTime {
                    // Rest timer
                    HStack(alignment: .bottom, spacing: Spacing.xs) {
                        Text("Rest: ")
                        Text(timerInterval: now...restEndTime)
                            .monospacedDigit()
                            .foregroundStyle(.tint)
                    }
            
            } else {
                // Elapsed time
                HStack(spacing: Spacing.xs) {
                    Text("Elapsed: ")
                    Text(active.dateCreated, style: .timer)
                        .monospacedDigit()
                }
            }
        }
        .foregroundStyle(.secondary)
        .font(.rowDetail)
        .multilineTextAlignment(.leading)
    }
}

extension CoreBuilder {
    func trainingAccessoryView(router: AnyRouter, delegate: TrainingAccessoryDelegate) -> some View {
        return TrainingAccessoryView(
            presenter: TrainingAccessoryPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView(addNavigationStack: false) { router in
        TabView {
            Tab {
                Text("Tab")
            } label: {
                Text("Tab")
            }
        }
        .tabViewBottomAccessory {
            builder.trainingAccessoryView(
                router: router, 
                delegate: TrainingAccessoryDelegate(active: .mock)
            )
        }
    }
}
