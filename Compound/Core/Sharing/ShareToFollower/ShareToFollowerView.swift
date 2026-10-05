//
//  ShareToFollowerView.swift
//  Compound
//

import SwiftUI

struct ShareToFollowerDelegate {
    let payload: ShareModel.Payload
}

struct ShareToFollowerView: View {

    @State var presenter: ShareToFollowerPresenter

    var body: some View {
        List {
            if presenter.recipients.isEmpty {
                ContentUnavailableView(
                    "No one to share with",
                    systemImage: "person.2.slash",
                    description: Text("You can share with people you follow who follow you back.")
                )
            } else {
                Section {
                    ForEach(presenter.recipients) { user in
                        recipientRow(user)
                    }
                } footer: {
                    Text("People you follow who follow you back.")
                }
            }
        }
        .navigationTitle("Share \(presenter.delegate.payload.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onCancelPressed()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if presenter.isSending {
                    ProgressView()
                } else {
                    Button(role: .confirm) {
                        presenter.onSendPressed()
                    }
                    .accessibilityLabel("Send")
                    .disabled(!presenter.canSend)
                }
            }
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    private func recipientRow(_ user: UserModel) -> some View {
        HStack(spacing: Spacing.m) {
            UserAvatarView(imageUrl: user.profileImageNameCalculated, size: ControlSize.thumbnail)
            Text(user.fullNameCalculated ?? "User")
                .font(.rowTitle)
            Spacer()
            Image(systemName: presenter.isSelected(user) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(presenter.isSelected(user) ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
        }
        .contentShape(Rectangle())
        .anyButton {
            presenter.onRecipientPressed(user)
        }
        .accessibilityAddTraits(presenter.isSelected(user) ? .isSelected : [])
    }
}

extension CoreBuilder {
    func shareToFollowerView(router: AnyRouter, delegate: ShareToFollowerDelegate) -> some View {
        ShareToFollowerView(
            presenter: ShareToFollowerPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }
}

extension CoreRouter {
    func showShareToFollowerView(delegate: ShareToFollowerDelegate) {
        router.showScreen(.sheet) { router in
            builder.shareToFollowerView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.shareToFollowerView(router: router, delegate: ShareToFollowerDelegate(payload: .template(.mock)))
    }
}
