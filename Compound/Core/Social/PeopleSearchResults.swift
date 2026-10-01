//
//  PeopleSearchResults.swift
//  Compound
//
//  What Social shows while its search field is active. Before anything is typed, the two ways to
//  bring someone in who cannot be searched for yet: sharing an invite, or typing a friend's code.
//

import SwiftUI

struct PeopleSearchResults: View {

    let search: PeopleSearch
    let followState: (UserModel) -> FollowState
    let onFollowPressed: (UserModel) -> Void
    let onPersonPressed: (UserModel) -> Void
    let onInviteFriendPressed: () -> Void
    let onEnterInviteCodePressed: () -> Void

    var body: some View {
        if !search.isSearching {
            Section {
                ListRowButton(title: String(localized: "Invite a Friend"), systemImage: "square.and.arrow.up", accessory: .none) {
                    onInviteFriendPressed()
                }
                ListRowButton(title: String(localized: "Enter Invite Code"), systemImage: "person.badge.plus", accessory: .none) {
                    onEnterInviteCodePressed()
                }
            } footer: {
                Text("Search by name or @username, or bring a friend in with an invite.")
            }
        } else if search.hasResults || search.isLoading {
            Section {
                if search.failed {
                    InlineMessage(.warning, "Couldn't search people. Check your connection.")
                }
                ForEach(search.results) { user in
                    UserRowView(user: user) {
                        FollowButton(state: followState(user)) {
                            onFollowPressed(user)
                        }
                    }
                    .tappableBackground()
                    .anyButton(.highlight) {
                        onPersonPressed(user)
                    }
                }
            } header: {
                HStack {
                    Text("People")
                    if search.isLoading {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
            }
        } else {
            ContentUnavailableView.search(text: search.query)
                .removeListRowFormatting()
        }
    }
}

/// The code from a friend's invite link, for a link opened on another device than the one with
/// the app.
struct InviteCodeSheet: View {

    @Binding var code: String
    let canJoin: Bool
    let onClose: () -> Void
    let onJoin: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.join)
                        .onSubmit(onJoin)
                } footer: {
                    Text("The 8-character code from a friend's invite link.")
                }
            }
            .navigationTitle("Enter Invite Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join", role: .confirm, action: onJoin)
                        .disabled(!canJoin)
                }
            }
        }
        .presentationDetents([.fraction(0.35), .large])
        .presentationDragIndicator(.visible)
    }
}
