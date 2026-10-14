//
//  NameWorkoutView.swift
//  Compound
//
//  Created by Andrew Coyle on 24/09/2025.
//

import SwiftUI
import PhotosUI

struct NameWorkoutDelegate {
    var workoutTemplate: WorkoutTemplateModel?
}

struct NameWorkoutView: View {

    @State var presenter: NameWorkoutPresenter

    var delegate: NameWorkoutDelegate

    @FocusState private var isNameFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField("Enter workout name", text: $presenter.workoutName)
                    .focused($isNameFocused)
                    .submitLabel(.continue)
                    .onSubmit {
                        presenter.onNameSubmitted(delegate: delegate)
                    }
                    .accessibilityIdentifier("NameWorkout.name")
            } header: {
                Text("Workout Name")
            }
        }
        .navigationTitle(delegate.workoutTemplate == nil ? String(localized: "Name Workout") : String(localized: "Edit Workout"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The wizard opens on this screen, so it carries the cover's close.
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onClosePressed()
                }
            }
        }
        .onAppear {
            presenter.onViewAppear()
            // A new workout's first job is its name, so the keyboard is already up.
            if delegate.workoutTemplate == nil { isNameFocused = true }
        }
        .onDisappear { presenter.onViewDisappear() }
        .bottomCTA {
            CallToActionButton {
                presenter.onContinuePressed(delegate: delegate)
            } label: {
                Text("Continue")
            }
            .accessibilityIdentifier("NameWorkout.continue")
            .disabled(!presenter.canSave)
        }
    }
}

extension CoreBuilder {
    func nameWorkoutView(router: AnyRouter, delegate: NameWorkoutDelegate) -> some View {
        NameWorkoutView(
            presenter: NameWorkoutPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                workoutName: delegate.workoutTemplate?.name ?? "",
                draftExercises: delegate.workoutTemplate?.exercises ?? []
            ),
            delegate: delegate
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)

    RouterView { router in
        builder.nameWorkoutView(router: router, delegate: NameWorkoutDelegate())
    }
    
}
