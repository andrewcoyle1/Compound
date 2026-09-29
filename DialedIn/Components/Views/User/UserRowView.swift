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
    var size: CGFloat = 44

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
    }
}

/// A person in a list: picture, name, and whatever the screen wants on the trailing edge.
struct UserRowView<Trailing: View>: View {

    let user: UserModel
    var avatarSize: CGFloat = 44
    @ViewBuilder var trailing: () -> Trailing

    private var displayName: String {
        user.fullNameCalculated ?? user.firstNameCalculated ?? "Unknown"
    }

    var body: some View {
        HStack(spacing: 12) {
            UserAvatarView(imageUrl: user.profileImageNameCalculated, size: avatarSize)

            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                UsernameLabel(username: user.username)
            }

            Spacer(minLength: 0)

            trailing()
        }
        .padding(.vertical, 6)
    }
}

extension UserRowView where Trailing == EmptyView {

    init(user: UserModel, avatarSize: CGFloat = 44) {
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
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isFilled ? Color.accentColor : Color(.secondarySystemBackground))
                // The accent is the label colour, so a filled capsule needs the background colour on top, not white.
                .foregroundStyle(isFilled ? Color(.systemBackground) : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
