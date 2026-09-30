//
//  SharedItemView.swift
//  DialedIn
//

import SwiftUI

struct SharedItemDelegate {
    let share: ShareModel
    let senderName: String
    /// Pushed when opened from inside the Notifications sheet, where the system Back button
    /// replaces its own Close. Sheeted everywhere else.
    var isPushed: Bool = false
}

/// A shared template or program, read-only, with the choice to copy it into the library.
struct SharedItemView: View {

    @State var presenter: SharedItemPresenter

    var body: some View {
        List {
            Section {
                Text("\(presenter.delegate.senderName) shared this with you.")
                    .foregroundStyle(.secondary)
            }
            if case .program(let program) = presenter.delegate.share.payload {
                Section {
                    TrainingProgramHeader(program: program)
                }
            }
            ForEach(presenter.templates) { template in
                Section {
                    ForEach(template.exercises) { item in
                        ListRow(
                            title: item.exercise.name,
                            imageName: item.exercise.imageURL,
                            resizingMode: .fit,
                            initialsWhenMissing: true,
                            accessory: .value(String(localized: "\(item.setTargets.count) sets"))
                        )
                    }
                } header: {
                    Text(template.name)
                }
            }
        }
        .navigationTitle(presenter.delegate.share.payload.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !presenter.delegate.isPushed {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        presenter.onClosePressed()
                    }
                }
            }
        }
        .bottomCTA {
            if presenter.isAnswered {
                Text(presenter.status == .accepted ? String(localized: "Added to your library") : String(localized: "Dismissed"))
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                CallToActionButton(isPrimaryAction: true, isLoading: presenter.isWorking) {
                    presenter.onAddToLibraryPressed()
                } label: {
                    Text("Add to Library")
                }
                .disabled(presenter.isWorking)
                Button("Decline") {
                    presenter.onDismissSharePressed()
                }
                .disabled(presenter.isWorking)
            }
        }
        .onAppear {
            presenter.onViewAppear()
        }
    }
}

extension CoreBuilder {
    func sharedItemView(router: AnyRouter, delegate: SharedItemDelegate) -> some View {
        SharedItemView(
            presenter: SharedItemPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }
}

extension CoreRouter {
    func showSharedItemView(delegate: SharedItemDelegate) {
        router.showScreen(delegate.isPushed ? .push : .sheet) { router in
            builder.sharedItemView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.sharedItemView(router: router, delegate: SharedItemDelegate(share: ShareModel.mocks[1], senderName: "Charlie"))
    }
}
