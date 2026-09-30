//
//  UserRowView.swift
//  DialedIn
//
//  One avatar and one person-row, shared by every screen that lists people. The Add tab's search
//  results, the followers list and the social profile each had their own copy, at three different
//  sizes with three different fallbacks for a missing picture.
//

import SwiftUI

/// A person's picture, falling back to the system person glyph.
struct UserAvatarView: View {

    let imageUrl: String?
    var size: CGFloat = ControlSize.row

    var body: some View {
        ZStack {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)

            if let imageUrl {
                ImageLoaderView(urlString: imageUrl, clipShape: AnyShape(Circle()))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        // The name beside it already says who this is; the picture adds nothing to VoiceOver.
        .accessibilityHidden(true)
    }
}

/// A person in a list: picture, name, and whatever the screen wants on the trailing edge.
struct UserRowView<Trailing: View>: View {

    let user: UserModel
    var avatarSize: CGFloat = ControlSize.row
    @ViewBuilder var trailing: () -> Trailing

    private var displayName: String {
        user.fullNameCalculated ?? user.firstNameCalculated ?? String(localized: "Unknown")
    }

    var body: some View {
        HStack(spacing: Spacing.m) {
            UserAvatarView(imageUrl: user.profileImageNameCalculated, size: avatarSize)

            VStack(alignment: .leading, spacing: 0) {
                Text(displayName)
                    .font(.rowTitle)
                    .fontWeight(.medium)
                    .lineLimit(1)
                UsernameLabel(username: user.username)
            }

            Spacer(minLength: 0)

            trailing()
        }
        .padding(.vertical, Spacing.xs)
    }
}

extension UserRowView where Trailing == EmptyView {

    init(user: UserModel, avatarSize: CGFloat = ControlSize.row) {
        self.init(user: user, avatarSize: avatarSize, trailing: { EmptyView() })
    }
}

/// The Follow / Following / Requested pill shown beside a person. What a tap does is the
/// presenter's call — see `FollowFlow`.
struct FollowButton: View {

    let state: FollowState
    let action: () -> Void

    private var title: String {
        switch state {
        case .follow: String(localized: "Follow")
        case .following: String(localized: "Following")
        case .requested: String(localized: "Requested")
        }
    }

    private var isFilled: Bool { state == .follow }

    var body: some View {
        // Follow is the primary action, so it is the accent; Following and Requested are secondary.
        Group {
            if isFilled {
                Button(title, action: action)
                    .buttonStyle(.borderedProminent)
                    // The label is drawn on the accent, so it needs onAccent, not the accent's own colour.
                    .foregroundStyle(.onAccent)
            } else {
                Button(title, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .font(.rowDetail)
        .fontWeight(.semibold)
        // Regular size, not `.small`: this is one of the most repeated taps in the app, and the
        // small glass capsule came in well under the 44 pt minimum.
        .accessibilityHint(state == .requested ? "Cancels your follow request" : "")
    }
}

#Preview {
    List {
        UserRowView(user: .mock)
        UserRowView(user: .mock) {
            FollowButton(state: .follow, action: { })
        }
        UserRowView(user: .mock) {
            FollowButton(state: .following, action: { })
        }
        UserRowView(user: .mock) {
            FollowButton(state: .requested, action: { })
        }
    }
}
