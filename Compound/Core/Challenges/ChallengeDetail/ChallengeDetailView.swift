//
//  ChallengeDetailView.swift
//  Compound
//

import SwiftUI

struct ChallengeDetailDelegate {
    let challenge: ChallengeModel
}

struct ChallengeDetailView: View {

    @State var presenter: ChallengeDetailPresenter
    @ScaledMetric(relativeTo: .subheadline) private var rankWidth: CGFloat = 24

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
                        Image(systemName: Symbol.more)
                    }
                    .accessibilityLabel("More")
                }
            }
        }
        .onAppear { presenter.onViewAppear() }
        .task { await presenter.loadStandings() }
    }

    private var header: some View {
        HStack(spacing: Spacing.l) {
            ChallengeRing(sessions: presenter.mySessions, target: presenter.challenge.targetSessions, size: 88)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Train \(presenter.challenge.targetSessions) times")
                    .font(.sectionTitle)
                Text(presenter.daysLeftText)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                Text(presenter.challenge.startsAt.formatted(date: .abbreviated, time: .omitted)
                     + " – " + presenter.challenge.endsAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.xs)
    }

    private func row(_ entry: ChallengeStandings.Entry, rank: Int) -> some View {
        let isOwn = entry.userId == presenter.currentUserId
        return Button {
            presenter.onMemberPressed(entry)
        } label: {
            HStack(spacing: Spacing.m) {
                Text(rank, format: .number)
                    .font(.rowDetail.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: rankWidth)
                UserAvatarView(imageUrl: entry.imageUrl, size: ControlSize.thumbnail)
                Text(isOwn ? String(localized: "You") : entry.name)
                    .font(.rowTitle)
                    .fontWeight(isOwn ? .semibold : .regular)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if entry.isComplete {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.success)
                        .accessibilityLabel("Finished")
                }
                Text("\(entry.sessions)/\(presenter.challenge.targetSessions)")
                    .font(.metricSmall)
                    .foregroundStyle(.secondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rank). \(isOwn ? String(localized: "You") : entry.name), \(entry.sessions) of \(presenter.challenge.targetSessions) sessions")
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
