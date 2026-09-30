import SwiftUI

struct FollowersListDelegate {
    let followers: [UserModel]
    /// The screen is reached as "Followers", "Following" and "People you both follow", so the title
    /// travels with the list rather than being hardcoded to one of them.
    var title: String = "Followers"
    /// Set only for the reader's own followers, whose rows can then be removed.
    var canRemoveFollowers: Bool = false
}

struct FollowersListView: View {
    
    @State var presenter: FollowersListPresenter
    let delegate: FollowersListDelegate

    var body: some View {
        List {
            if delegate.followers.isEmpty {
                // The list was drawn straight from the array, so an empty one was a blank screen.
                ContentUnavailableView(
                    "No Followers Yet",
                    systemImage: Symbol.friends,
                    description: Text("People will show up here once there are some.")
                )
                .removeListRowFormatting()
            } else {
                ForEach(presenter.visibleFollowers(delegate.followers)) { user in
                    UserRowView(user: user) {
                        if presenter.showsFollowButton(for: user) {
                            FollowButton(state: presenter.followState(for: user)) {
                                presenter.onFollowButtonPressed(user: user)
                            }
                        }
                    }
                    .tappableBackground()
                    .anyButton(.highlight) {
                        presenter.onUserPressed(user: user)
                    }
                    .rowActions {
                        if delegate.canRemoveFollowers {
                            // Not `.destructive`: that role animates the row away before the
                            // confirmation has been answered.
                            Button {
                                presenter.onRemoveFollowerPressed(user: user)
                            } label: {
                                Label("Remove", systemImage: Symbol.delete)
                            }
                            .tint(.danger)
                        }
                    }
                }
            }
        }
        .navigationTitle(delegate.title)
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = FollowersListDelegate(followers: UserModel.mocks)
    
    RouterView { router in
        builder.followersListView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    func followersListView(router: AnyRouter, delegate: FollowersListDelegate) -> some View {
        FollowersListView(
            presenter: FollowersListPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showFollowersList(delegate: FollowersListDelegate) {
        router.showScreen(.push) { router in
            builder.followersListView(router: router, delegate: delegate)
        }
    }
}
