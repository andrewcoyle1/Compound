//
//  CreateWorkoutView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 24/09/2025.
//

import SwiftUI
import PhotosUI

struct CreateWorkoutDelegate {
    /// Set when editing; the wizard opens prefilled and the save updates this template.
    var workoutTemplate: WorkoutTemplateModel?
}

struct CreateWorkoutView: View {

    @State var presenter: CreateWorkoutPresenter

    var delegate: CreateWorkoutDelegate

    var body: some View {
        VStack(spacing: 0) {
            ImageLoaderView()
                .ignoresSafeArea()
                .frame(maxHeight: 400)
            // The heading sits under the hero image: an inline bar title over the image was
            // unreadable. `navigationTitle` stays for VoiceOver and the back menu.
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Create Workout")
                    .font(.display)
                    .accessibilityAddTraits(.isHeader)
                Text("You will create a new workout for your library.")
                    .font(.rowTitle)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .navigationTitle("Create Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
        .bottomCTA {
            CallToActionButton {
                presenter.onContinuePressed(delegate: delegate)
            } label: {
                Text("Continue")
            }
            .accessibilityIdentifier("CreateWorkout.continue")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.cancel()
                }
            }
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
        RouterView { router in
            builder.createWorkoutView(router: router, delegate: CreateWorkoutDelegate(workoutTemplate: .mock))
        }
    
}

extension CoreBuilder {
    /// Editing skips the splash: the template already exists, so the cover opens on its name.
    @ViewBuilder
    func createWorkoutView(router: AnyRouter, delegate: CreateWorkoutDelegate) -> some View {
        if let template = delegate.workoutTemplate {
            nameWorkoutView(
                router: router,
                delegate: NameWorkoutDelegate(workoutTemplate: template)
            )
        } else {
            CreateWorkoutView(
                presenter: CreateWorkoutPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
                delegate: delegate
            )
        }
    }
}

extension CoreRouter {
    func showCreateWorkoutView(delegate: CreateWorkoutDelegate) {
        router.showScreen(.fullScreenCover) { router in
            builder.createWorkoutView(router: router, delegate: delegate)
        }
    }
}
