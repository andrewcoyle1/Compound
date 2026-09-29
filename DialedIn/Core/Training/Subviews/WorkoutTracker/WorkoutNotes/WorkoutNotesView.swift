//
//  WorkoutNotesView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 05/12/2025.
//

import SwiftUI

struct WorkoutNotesDelegate {
    var notes: Binding<String>
    let onSave: () -> Void
    var title: String = "Workout Notes"
    /// Shown greyed above the editor, e.g. the note left on this exercise last session.
    var hint: String?
    var saveTitle: String = "Save"
    /// Runs once the sheet is fully gone, whichever button closed it. The finish screen uses it
    /// to end the workout only after its own sheet is out of the way.
    var onDidDismiss: (() -> Void)?
}

struct WorkoutNotesView: View {

    @State var presenter: WorkoutNotesPresenter
    
    var delegate: WorkoutNotesDelegate

    var body: some View {
        VStack(alignment: .leading) {
            if let hint = delegate.hint {
                Text("Last time: \(hint)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top)
            }
            TextEditor(text: delegate.notes)
                .padding()
                .background(Color.secondaryBackground, in: .rect(cornerRadius: 24))
                .padding()
            Spacer()
        }
        .navigationTitle(delegate.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") {
                presenter.onDismissPressed()
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(delegate.saveTitle) {
                delegate.onSave()
                presenter.onDismissPressed()
            }
        }
    }
}

extension CoreBuilder {
    func workoutNotesView(router: AnyRouter, delegate: WorkoutNotesDelegate) -> some View {
        WorkoutNotesView(
            presenter: WorkoutNotesPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showWorkoutNotesView(delegate: WorkoutNotesDelegate) {
        router.showScreen(.sheet, onDidDismiss: delegate.onDidDismiss) { router in
            builder.workoutNotesView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    List {
        Text("Hello")
    }
    .sheet(isPresented: .constant(true)) {
        RouterView { router in
            builder.workoutNotesView(
                router: router,
                delegate: WorkoutNotesDelegate(
                    notes: Binding.constant(""),
                    onSave: {
                        
                    }
                )
            )
        }
    }
}
