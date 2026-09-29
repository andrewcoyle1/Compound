//
//  CommentsView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

import SwiftUI

struct CommentsDelegate {
    let session: WorkoutSessionModel
}

struct CommentsView: View {

    @State var presenter: CommentsPresenter

    var body: some View {
        List {
            if presenter.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .removeListRowFormatting()
            } else if presenter.loadFailed {
                ContentUnavailableView {
                    Label("Unable to Load Comments", systemImage: Symbol.warning)
                } description: {
                    Text("Check your connection and try again.")
                } actions: {
                    Button("Try Again") {
                        presenter.onRetryLoadPressed()
                    }
                }
                .removeListRowFormatting()
            } else if presenter.comments.isEmpty {
                ContentUnavailableView(
                    "No Comments Yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Start the conversation.")
                )
                .removeListRowFormatting()
            } else {
                Section {
                    ForEach(presenter.comments) { comment in
                        commentRow(comment)
                            .padding(.leading, presenter.isReply(comment) ? ControlSize.thumbnail : 0)
                            .rowActions(edge: .leading) {
                                Button {
                                    presenter.onReplyPressed(comment)
                                } label: {
                                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                                }
                                .tint(.accentColor)
                            }
                            .rowActions(edge: .trailing) {
                                if presenter.isOwnComment(comment) {
                                    Button(role: .destructive) {
                                        presenter.onDeletePressed(comment)
                                    } label: {
                                        Label("Delete", systemImage: Symbol.delete)
                                    }
                                    .tint(.danger)
                                } else {
                                    Button {
                                        presenter.onReportPressed(comment)
                                    } label: {
                                        Label("Report", systemImage: "flag.fill")
                                    }
                                    .tint(.warning)
                                }
                            }
                    }
                    .listSectionMargins(.top, 0)

                }
            }
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .onAppear {
            presenter.onViewAppear()
        }
        .safeAreaInset(edge: .bottom) {
            inputBar
        }
    }

    private func commentRow(_ comment: WorkoutSessionComment) -> some View {
        // Top-aligned: the avatar and the heart belong beside the name, not the middle of a row
        // that the Reply button made taller.
        HStack(alignment: .top) {
            // `Constants.randomImage` was the fallback here, so a commenter with no picture was
            // given someone else's at random, and a different one on every redraw.
            UserAvatarView(imageUrl: comment.authorImageUrl, size: ControlSize.thumbnail)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(comment.authorName ?? String(localized: "Unknown"))
                        .font(.rowDetail)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(comment.dateCreated.formatted(.relative(presentation: .named)))
                        .font(.label)
                        .foregroundStyle(.secondary)
                }
                Text(presenter.attributedText(for: comment))
                    .font(.rowDetail)
                Button {
                    presenter.onReplyPressed(comment)
                } label: {
                    Text("Reply")
                        .font(.label)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: ControlSize.row, alignment: .leading)
                        .contentShape(.rect)
                        // The 44 pt hit area laid out as 28 pt: it overhangs the gap above and the
                        // row's padding below, so Reply sits under the comment without a blank band.
                        // More overhang would reach over the text and take taps meant for a mention.
                        .padding(.vertical, -Spacing.s)
                }
                .buttonStyle(.plain)
            }
            likeButton(comment)
        }
        .padding(.vertical, Spacing.xs)
    }

    private func likeButton(_ comment: WorkoutSessionComment) -> some View {
        let isLiked = presenter.isLikedByReader(comment)
        let count = comment.likedByUserIds.count
        return Button {
            presenter.onLikePressed(comment)
        } label: {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(isLiked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .contentTransition(.symbolEffect(.replace))
                if count > 0 {
                    Text(count, format: .number)
                        .font(.label)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .tapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLiked ? String(localized: "Unlike comment") : String(localized: "Like comment"))
        .accessibilityValue(count == 1 ? String(localized: "1 like") : String(localized: "\(count) likes"))
    }

    private var inputBar: some View {
        VStack(spacing: Spacing.s) {
            if let parent = presenter.replyingTo {
                HStack {
                    Text("Replying to \(parent.authorName ?? String(localized: "comment"))")
                        .font(.label)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        presenter.onCancelReplyPressed()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .tapTarget()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Cancel reply")
                }
            }
            if !presenter.mentionSuggestions.isEmpty {
                mentionSuggestionRow
            }
            inputRow
        }
        .padding()
        .glassEffect(in: .containerRelative)
        .padding()
    }

    private var mentionSuggestionRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.s) {
                ForEach(presenter.mentionSuggestions) { candidate in
                    Button {
                        presenter.onMentionSuggestionPressed(candidate)
                    } label: {
                        Text(candidate.label)
                            .font(.rowDetail)
                            .padding(.horizontal, Spacing.s)
                            .padding(.vertical, Spacing.xs)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Mention \(candidate.fullName)")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var inputRow: some View {
        HStack(spacing: Spacing.s) {
            TextField(presenter.replyingTo == nil ? String(localized: "Add a comment…") : String(localized: "Add a reply…"), text: $presenter.commentDraft, axis: .vertical)
                .lineLimit(1...4)
            Button {
                presenter.onSendPressed()
            } label: {
                Image(systemName: "paperplane.fill")
                    .tapTarget()
            }
            .accessibilityLabel("Send comment")
            .disabled(presenter.commentDraft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

// MARK: - Previews

/// The shipped mock comments all sit on `session-1`, which is the *oldest* mock session, so a
/// preview built straight from `DevPreview` renders the empty state. These previews register a
/// comments service scoped to the session actually being shown.
@MainActor
private func commentsPreviewContainer(
    comments: [WorkoutSessionComment]?,
    delay: Double = 0.0,
    showError: Bool = false
) -> DependencyContainer {
    let container = DevPreview.shared.container()
    container.register(
        CommentsManager.self,
        service: CommentsManager(
            service: MockCommentsService(comments: comments, delay: delay, showError: showError)
        )
    )
    return container
}

#Preview("Comments") {
    let session = WorkoutSessionModel.mock
    let container = commentsPreviewContainer(comments: WorkoutSessionComment.mocks(sessionId: session.id))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    RouterView { router in
        builder.commentsView(router: router, delegate: CommentsDelegate(session: session))
    }
}

#Preview("Empty") {
    let session = WorkoutSessionModel.mock
    let container = commentsPreviewContainer(comments: [])
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    RouterView { router in
        builder.commentsView(router: router, delegate: CommentsDelegate(session: session))
    }
}

#Preview("Loading") {
    let session = WorkoutSessionModel.mock
    let container = commentsPreviewContainer(
        comments: WorkoutSessionComment.mocks(sessionId: session.id),
        delay: 60
    )
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    RouterView { router in
        builder.commentsView(router: router, delegate: CommentsDelegate(session: session))
    }
}

#Preview("Load Failed") {
    let session = WorkoutSessionModel.mock
    let container = commentsPreviewContainer(comments: nil, showError: true)
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    RouterView { router in
        builder.commentsView(router: router, delegate: CommentsDelegate(session: session))
    }
}

#Preview("Draft Typed") {
    let session = WorkoutSessionModel.mock
    let comments = WorkoutSessionComment.mocks(sessionId: session.id)
    let container = commentsPreviewContainer(comments: comments)
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)

    RouterView { router in
        CommentsView(
            presenter: CommentsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: builder),
                delegate: CommentsDelegate(session: session)
            )
            .withPreviewState(comments: comments, draft: "Nice work — what did that top single feel like?")
        )
    }
}

#Preview("Long List") {
    let session = WorkoutSessionModel.mock
    let container = commentsPreviewContainer(comments: WorkoutSessionComment.manyMocks(sessionId: session.id))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    RouterView { router in
        builder.commentsView(router: router, delegate: CommentsDelegate(session: session))
    }
}

extension CoreBuilder {
    func commentsView(router: AnyRouter, delegate: CommentsDelegate) -> some View {
        CommentsView(
            presenter: CommentsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }
}
