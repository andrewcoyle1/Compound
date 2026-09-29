//
//  NameWorkoutView.swift
//  DialedIn
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

    var body: some View {
        List {
            Section {
                TextField("Enter workout name", text: $presenter.workoutName)
                    .accessibilityIdentifier("NameWorkout.name")
            } header: {
                Text("Workout name")
            }
        }
        .navigationTitle(delegate.workoutTemplate == nil ? String(localized: "Name Workout") : String(localized: "Edit Workout"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Editing opens straight onto this screen, so it needs the close the splash normally has.
            if delegate.workoutTemplate != nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        presenter.onClosePressed()
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
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
                workoutName: delegate.workoutTemplate?.name ?? ""
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showNameWorkoutView(delegate: NameWorkoutDelegate) {
        router.showScreen(.push) { router in
            builder.nameWorkoutView(router: router, delegate: delegate)
        }
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
