//
//  CircleActivityStripView.swift
//  DialedIn
//
//  The row of faces at the top of the Dashboard feed: who in the user's circle has trained today.
//

import SwiftUI

/// One person in the strip, derived by `DashboardPresenter.circleMembers`.
struct CircleMember: Identifiable {
    let user: UserModel
    /// Finished a non-rest session today, by the device's calendar.
    let trainedToday: Bool
    /// Not trained, not the user, and not already nudged today.
    let canNudge: Bool
    /// Finished sessions this week and the person's goal, for the ring round the face.
    var sessionsThisWeek = 0
    var weeklyGoal = CircleWeek.defaultGoal
    /// Set only on the user's own face, on the last day of the week, while they are short of goal.
    var sessionsToGo: Int?
    var isCurrentUser = false

    var weeklyProgress: Double {
        CircleWeek.progress(sessions: sessionsThisWeek, goal: weeklyGoal)
    }

    var id: String { user.userId }

    var name: String {
        user.commonNameCalculated ?? user.fullNameCalculated ?? "Unknown"
    }
}

/// Full colour with a check for anyone who has trained today, greyed otherwise. The nudge is a
/// visible button under the greyed face rather than a long-press menu: a context menu on an
/// avatar is invisible until someone happens to hold it, and the nudge is the point of the strip.
struct CircleActivityStripView: View {

    let members: [CircleMember]
    let onMemberPressed: (CircleMember) -> Void
    let onNudgePressed: (CircleMember) -> Void
    /// Shown under the user's own face while they have no weekly goal.
    var onSetGoalPressed: (() -> Void)?

    private let avatarSize: CGFloat = 52
    /// Grows with the text so "Nudge" and the name keep to one line at accessibility sizes,
    /// instead of wrapping a letter per line inside a column sized for the face.
    @ScaledMetric(relativeTo: .caption) private var cellWidth: CGFloat = 64

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(members) { member in
                    memberCell(member)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }

    private func memberCell(_ member: CircleMember) -> some View {
        VStack(spacing: 6) {
            Button {
                onMemberPressed(member)
            } label: {
                VStack(spacing: 4) {
                    avatar(member)
                    if let toGo = member.sessionsToGo {
                        Text("\(toGo) to go")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        // First name only: a full name under a 56pt face truncates to "Alice Coo…".
                        Text(member.user.firstNameCalculated ?? member.name)
                            .font(.caption)
                            .foregroundStyle(member.trainedToday ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(member.name), \(member.trainedToday ? String(localized: "trained today") : String(localized: "not trained yet today")), "
                + "\(member.sessionsThisWeek) of \(member.weeklyGoal) sessions this week"
            )
            .accessibilityHint("Opens their profile")

            if member.canNudge {
                Button("Nudge") {
                    onNudgePressed(member)
                }
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.mini)
                .accessibilityLabel("Nudge \(member.name) to train")
            }

            if member.isCurrentUser, let onSetGoalPressed {
                Button("Set goal", action: onSetGoalPressed)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.mini)
                    .accessibilityLabel("Set your weekly session goal")
            }
        }
        .frame(width: max(avatarSize + 16, cellWidth))
    }

    /// The ring is the week's sessions over goal; the check is still today.
    private func avatar(_ member: CircleMember) -> some View {
        UserAvatarView(imageUrl: member.user.profileImageNameCalculated, size: avatarSize)
            .grayscale(member.trainedToday ? 0 : 1)
            .opacity(member.trainedToday ? 1 : 0.5)
            .padding(4)
            .overlay {
                Circle()
                    .stroke(.quaternary, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: member.weeklyProgress)
                    .stroke(.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .overlay(alignment: .bottomTrailing) {
                if member.trainedToday {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.white, .green)
                        .background(Circle().fill(.background))
                }
            }
    }
}

#Preview {
    CircleActivityStripView(
        members: [
            CircleMember(user: .mock, trainedToday: true, canNudge: false, sessionsThisWeek: 2, sessionsToGo: 1, isCurrentUser: true),
            CircleMember(user: UserModel(userId: "b", submittedFirstName: "Sam"), trainedToday: false, canNudge: true),
            CircleMember(user: UserModel(userId: "c", submittedFirstName: "Alex"), trainedToday: false, canNudge: false)
        ],
        onMemberPressed: { _ in },
        onNudgePressed: { _ in },
        onSetGoalPressed: { }
    )
}
