//
//  ChallengeDetailView.swift
//  DialedIn
//

import SwiftUI

struct ChallengeDetailDelegate {
    let challenge: ChallengeModel
}

struct ChallengeDetailView: View {

    @State var presenter: ChallengeDetailPresenter

    var body: some View {
        List {
            Section {
                header
            }
            Section("Standings") {
                ForEach(Array(presenter.standings.enumerated()), id: \.element.id) { index, entry in
                    row(entry, rank: index + 1)
                }
            }
        }
        .navigationTitle(presenter.challenge.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if presenter.isMember {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Leave Challenge", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            presenter.onLeavePressed()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More")
                }
            }
        }
        .onAppear { presenter.onViewAppear() }
        .task { await presenter.loadStandings() }
    }

    private var header: some View {
        HStack(spacing: 16) {
            ChallengeRing(sessions: presenter.mySessions, target: presenter.challenge.targetSessions, size: 88)
            VStack(alignment: .leading, spacing: 4) {
                Text("Train \(presenter.challenge.targetSessions) times")
                    .font(.headline)
                Text(presenter.daysLeftText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(presenter.challenge.startsAt.formatted(date: .abbreviated, time: .omitted)
                     + " – " + presenter.challenge.endsAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func row(_ entry: ChallengeStandings.Entry, rank: Int) -> some View {
        let isOwn = entry.userId == presenter.currentUserId
        return Button {
            presenter.onMemberPressed(entry)
        } label: {
            HStack(spacing: 12) {
                Text("\(rank)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                UserAvatarView(imageUrl: entry.imageUrl, size: 36)
                Text(isOwn ? "You" : entry.name)
                    .font(.body.weight(isOwn ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if entry.isComplete {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Finished")
                }
                Text("\(entry.sessions)/\(presenter.challenge.targetSessions)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rank). \(isOwn ? "You" : entry.name), \(entry.sessions) of \(presenter.challenge.targetSessions) sessions")
    }
}

extension CoreBuilder {
    func challengeDetailView(router: AnyRouter, delegate: ChallengeDetailDelegate) -> some View {
        ChallengeDetailView(
            presenter: ChallengeDetailPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }
}

extension CoreRouter {
    func showChallengeDetailView(delegate: ChallengeDetailDelegate) {
        router.showScreen(.push) { router in
            builder.challengeDetailView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.challengeDetailView(router: router, delegate: ChallengeDetailDelegate(challenge: .mock))
    }
}
