//
//  CreateChallengeView.swift
//  DialedIn
//

import SwiftUI

struct CreateChallengeView: View {

    @State var presenter: CreateChallengePresenter

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $presenter.title)
                    .textInputAutocapitalization(.words)
                Stepper(value: $presenter.targetSessions, in: ChallengeModel.targetRange) {
                    Text("Target: \(presenter.targetSessions) sessions")
                }
                Picker("Duration", selection: $presenter.durationDays) {
                    ForEach(ChallengeModel.durations, id: \.self) { days in
                        Text("\(days) days").tag(days)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                if let message = presenter.validationMessage {
                    Text(message)
                }
            }

            Section {
                if presenter.candidates.isEmpty {
                    ContentUnavailableView(
                        "No one to invite",
                        systemImage: "person.2.slash",
                        description: Text("You can invite people you follow who follow you back.")
                    )
                } else {
                    ForEach(presenter.candidates) { user in
                        candidateRow(user)
                    }
                }
            } header: {
                Text("Members")
            } footer: {
                Text("People you follow who follow you back.")
            }
        }
        .navigationTitle("New Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    presenter.onCancelPressed()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    presenter.onCreatePressed()
                }
                .disabled(!presenter.canCreate)
            }
        }
        .onAppear { presenter.onViewAppear() }
    }

    private func candidateRow(_ user: UserModel) -> some View {
        HStack(spacing: 12) {
            UserAvatarView(imageUrl: user.profileImageNameCalculated, size: 36)
            Text(user.fullNameCalculated ?? "User")
            Spacer()
            Image(systemName: presenter.isSelected(user) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(presenter.isSelected(user) ? Color.accentColor : Color.secondary)
        }
        .contentShape(Rectangle())
        .anyButton {
            presenter.onCandidatePressed(user)
        }
        .accessibilityAddTraits(presenter.isSelected(user) ? .isSelected : [])
    }
}

extension CoreBuilder {
    func createChallengeView(router: AnyRouter) -> some View {
        CreateChallengeView(
            presenter: CreateChallengePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
}

extension CoreRouter {
    func showCreateChallengeView() {
        router.showScreen(.sheet) { router in
            builder.createChallengeView(router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.createChallengeView(router: router)
    }
}
