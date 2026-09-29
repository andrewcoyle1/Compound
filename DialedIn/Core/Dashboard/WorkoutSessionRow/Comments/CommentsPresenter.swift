//
//  CommentsPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 08/03/2026.
//

import SwiftUI

@Observable
@MainActor
class CommentsPresenter {

    private let interactor: CommentsInteractor
    private let router: CommentsRouter
    let reportFlow: ReportFlow
    let session: WorkoutSessionModel

    private(set) var comments: [WorkoutSessionComment] = []
    private(set) var isLoading = false
    var commentDraft: String = ""
    /// The comment the draft replies to, if any. Set by the row's Reply action, cleared by the
    /// bar's cancel or by sending.
    private(set) var replyingTo: WorkoutSessionComment?
    /// People picked from the suggestion row for the current draft. Only those whose `@FirstName`
    /// is still in the text when it is sent are recorded on the comment.
    private(set) var draftMentions: [CommentMentionCandidate] = []
    /// The session's author, fetched only when neither the reader's follows nor the thread
    /// already name them, so they can be mentioned before they have commented.
    private var sessionAuthor: UserModel?

    init(
        interactor: CommentsInteractor,
        router: CommentsRouter,
        delegate: CommentsDelegate
    ) {
        self.interactor = interactor
        self.router = router
        self.reportFlow = ReportFlow(interactor: interactor, router: router)
        self.session = delegate.session
    }

    func onViewAppear() {
        Task { await loadComments() }
    }

    private func loadComments() async {
        isLoading = true
        // Sorted here because the query that fetches them has no order clause, so they arrive in
        // document-id order — effectively at random. A reply read before the thing it replies to is
        // nonsense, and new comments are appended to the end, so the thread is oldest first.
        let fetched = (try? await interactor.fetchComments(sessionId: session.id)) ?? []
        comments = Self.threaded(hidingBlocked(fetched))
        isLoading = false
        if !knownPeople.contains(where: { $0.id == session.authorId }) {
            // Silent: the author is only needed for mention suggestions.
            sessionAuthor = try? await interactor.getUser(userId: session.authorId)
        }
    }

    /// Drops comments by anyone the reader has blocked, and comments hidden by moderation that are
    /// not the reader's own, along with the replies under them — which would otherwise surface at
    /// the top level as orphans.
    private func hidingBlocked(_ comments: [WorkoutSessionComment]) -> [WorkoutSessionComment] {
        guard let reader = interactor.currentUser else { return comments.filter { $0.hidden != true } }
        let hiddenIds = Set(comments.filter { reader.hasBlocked($0.authorId) || $0.isHidden(from: reader.userId) }.map(\.id))
        return comments.filter { comment in
            !hiddenIds.contains(comment.id) && !hiddenIds.contains(comment.parentId ?? "")
        }
    }

    /// Top-level comments oldest first, each followed by its replies oldest first. A reply whose
    /// parent is gone (deleted) is shown at the top level rather than dropped.
    static func threaded(_ comments: [WorkoutSessionComment]) -> [WorkoutSessionComment] {
        let byDate = comments.sorted { $0.dateCreated < $1.dateCreated }
        let ids = Set(byDate.map(\.id))
        let roots = byDate.filter { $0.parentId == nil || !ids.contains($0.parentId ?? "") }
        return roots.flatMap { root in
            [root] + byDate.filter { $0.parentId == root.id }
        }
    }

    func isReply(_ comment: WorkoutSessionComment) -> Bool {
        guard let parentId = comment.parentId else { return false }
        return comments.contains { $0.id == parentId }
    }

    func onReplyPressed(_ comment: WorkoutSessionComment) {
        // Replies stay one level deep: replying to a reply joins its thread.
        replyingTo = comments.first { $0.id == comment.parentId } ?? comment
    }

    func onCancelReplyPressed() {
        replyingTo = nil
    }

    func isOwnComment(_ comment: WorkoutSessionComment) -> Bool {
        comment.authorId == interactor.currentUser?.userId
    }

    func onSendPressed() {
        // Newlines as well as spaces: a draft of nothing but returns is not a comment, and trimming
        // only spaces let it through as a blank row under someone's workout.
        let trimmed = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let user = interactor.currentUser else { return }
        let comment = WorkoutSessionComment(
            id: UUID().uuidString,
            sessionId: session.id,
            sessionAuthorId: session.authorId,
            authorId: user.userId,
            authorName: user.fullNameCalculated,
            authorImageUrl: user.profileImageNameCalculated,
            text: trimmed,
            dateCreated: Date(),
            parentId: replyingTo?.id,
            mentionedUserIds: mentionedUserIds(in: trimmed)
        )
        let parent = replyingTo
        let mentions = draftMentions
        commentDraft = ""
        replyingTo = nil
        draftMentions = []
        // Shown at once: Firestore queues the write, and offline the await does not return until the
        // signal does, which left the comment invisible behind a spinner. Taken back if it fails.
        comments = Self.threaded(comments + [comment])
        Task {
            do {
                try await interactor.addComment(comment)
            } catch {
                comments.removeAll { $0.id == comment.id }
                replyingTo = parent
                draftMentions = mentions
                // Was `try?` followed by an unconditional append: a comment that never reached the
                // server still appeared in the list, and the draft was already cleared, so the text
                // was gone too.
                commentDraft = trimmed
                router.showSimpleAlert(title: String(localized: "Unable to Post Comment"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    // MARK: - Mentions

    /// Everyone who could be mentioned here, or appear as a mention: the reader, the people they
    /// follow, the session's author, and everyone who has commented in this thread. First occurrence wins, so a followed user's profile name beats
    /// the name frozen on an old comment.
    private var knownPeople: [CommentMentionCandidate] {
        let reader = interactor.currentUser.map { [$0] } ?? []
        let users = (reader + interactor.followingUsers + (sessionAuthor.map { [$0] } ?? [])).compactMap { user in
            user.fullNameCalculated.map { CommentMentionCandidate(id: user.userId, fullName: $0, username: user.username) }
        }
        let commenters = comments.compactMap { comment in
            comment.authorName.map { CommentMentionCandidate(id: comment.authorId, fullName: $0) }
        }
        var seen = Set<String>()
        return (users + commenters).filter { seen.insert($0.id).inserted }
    }

    /// The letters after a trailing `@` in the draft, or nil when the draft is not mid-mention.
    /// Digits, underscores and dots count too, since a handle can hold them.
    private var mentionQueryText: Substring? {
        commentDraft.firstMatch(of: #/(?:^|\s)@([\p{L}0-9_.]+)$/#)?.output.1
    }

    private var mentionQuery: String? {
        mentionQueryText?.lowercased()
    }

    /// Up to five people whose first or full name starts with what follows the `@`. Never the
    /// reader: mentioning yourself notifies nobody.
    var mentionSuggestions: [CommentMentionCandidate] {
        guard let query = mentionQuery else { return [] }
        let readerId = interactor.currentUser?.userId
        return Array(
            knownPeople
                .filter { $0.id != readerId }
                .filter {
                    $0.firstName.lowercased().hasPrefix(query)
                        || $0.fullName.lowercased().filter { !$0.isWhitespace }.hasPrefix(query)
                        || $0.username?.hasPrefix(query) == true
                }
                .prefix(5)
        )
    }

    func onMentionSuggestionPressed(_ candidate: CommentMentionCandidate) {
        guard let query = mentionQueryText else { return }
        commentDraft.replaceSubrange(query.startIndex..<commentDraft.endIndex, with: "\(candidate.mentionText) ")
        if !draftMentions.contains(candidate) {
            draftMentions.append(candidate)
        }
    }

    private func mentionedUserIds(in text: String) -> [String] {
        draftMentions.filter { text.contains("@\($0.mentionText)") }.map(\.id)
    }

    /// The comment's text with each resolvable `@FirstName` in the accent colour. A mention of
    /// someone the reader has never seen named stays plain.
    func attributedText(for comment: WorkoutSessionComment) -> AttributedString {
        // ponytail: names resolve only from the reader, their follows, the author and the thread;
        // store names on the comment if mentions of strangers need highlighting too.
        var result = AttributedString(comment.text)
        // Both spellings: comments written before handles existed mention by first name.
        let names = knownPeople.filter { comment.mentionedUserIds.contains($0.id) }.flatMap { [$0.firstName, $0.mentionText] }
        for name in Set(names) {
            var searchStart = result.startIndex
            while let range = result[searchStart...].range(of: "@\(name)") {
                result[range].foregroundColor = Color.accentColor
                searchStart = range.upperBound
            }
        }
        return result
    }

    /// The Report swipe action was a `Button` with an empty closure. `ReportManager` and its remote
    /// service were already built and wired into the container with no caller anywhere in the app;
    /// this was the first one.
    func onReportPressed(_ comment: WorkoutSessionComment) {
        reportFlow.start(ReportedContent(type: .comment, id: comment.id, authorUserId: comment.authorId, noun: "comment"))
    }

    // MARK: - Likes

    func isLikedByReader(_ comment: WorkoutSessionComment) -> Bool {
        guard let readerId = interactor.currentUser?.userId else { return false }
        return comment.likedByUserIds.contains(readerId)
    }

    /// Flips the heart at once and writes in the background, putting it back if the write fails.
    func onLikePressed(_ comment: WorkoutSessionComment) {
        guard let readerId = interactor.currentUser?.userId,
              let current = comments.first(where: { $0.id == comment.id }) else { return }
        let isLiked = !current.likedByUserIds.contains(readerId)
        setLike(isLiked, commentId: comment.id, userId: readerId)
        Task {
            do {
                try await interactor.toggleCommentLike(id: comment.id, userId: readerId, isLiked: isLiked)
            } catch {
                setLike(!isLiked, commentId: comment.id, userId: readerId)
            }
        }
    }

    private func setLike(_ isLiked: Bool, commentId: String, userId: String) {
        guard let index = comments.firstIndex(where: { $0.id == commentId }) else { return }
        comments[index].likedByUserIds.removeAll { $0 == userId }
        if isLiked {
            comments[index].likedByUserIds.append(userId)
        }
    }

    func onDeletePressed(_ comment: WorkoutSessionComment) {
        router.showAlert(title: String(localized: "Delete Comment?"), subtitle: String(localized: "Are you sure you want to delete your comment? This cannot be undone."), buttons: {
            AnyView(
                Button(role: .destructive) {
                    self.onDeleteConfirmed(comment)
                }
            )
        })
    }
    
    func onDeleteConfirmed(_ comment: WorkoutSessionComment) {
        // Removed at once, for the same reason a new comment is shown at once; put back if it fails.
        comments.removeAll { $0.id == comment.id }
        Task {
            do {
                try await interactor.deleteComment(id: comment.id)
            } catch {
                comments = Self.threaded(comments + [comment])
                // Was `try?` with an unconditional removal, so a failed delete looked like it worked
                // until the next refresh brought the comment back.
                router.showSimpleAlert(title: String(localized: "Unable to Delete Comment"), subtitle: String(localized: "Please try again."))
            }
        }
    }
 }

/// Someone who can be picked from the mention row. The inserted text is `@handle`, or `@firstName`
/// for someone without one; the id is what the comment records.
struct CommentMentionCandidate: Identifiable, Equatable {
    let id: String
    let fullName: String
    var username: String?

    /// What follows the `@` in the draft.
    var mentionText: String {
        username ?? firstName
    }

    /// The suggestion chip's title.
    var label: String {
        username.map { "@\($0)" } ?? fullName
    }

    var firstName: String {
        fullName.split(separator: " ").first.map(String.init) ?? fullName
    }
}

// MARK: - Preview support

extension CommentsPresenter {

    /// Seeds state directly so previews can render states that otherwise only exist mid-flight
    /// (a load in progress). `private(set)` is file-scoped, so this has to live next to the
    /// presenter rather than in the view file.
    @discardableResult
    func withPreviewState(
        comments: [WorkoutSessionComment]? = nil,
        isLoading: Bool = false,
        draft: String = ""
    ) -> CommentsPresenter {
        if let comments {
            self.comments = comments
        }
        self.isLoading = isLoading
        self.commentDraft = draft
        return self
    }
}
