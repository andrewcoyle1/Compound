import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/app/document_id.dart';
import 'package:compound/social/comments/comment_thread.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';

/// Where the thread's first read is.
enum CommentsStatus { loading, loaded, failed }

/// A write that failed, for the alert that says so.
enum CommentsNotice { postFailed, deleteFailed }

final class const CommentsState({
  final CommentsStatus status = CommentsStatus.loading,

  /// The thread, in reading order.
  final List<WorkoutSessionComment> comments = const [],

  /// What is typed.
  final String draft = '',

  /// The comment the draft replies to.
  final WorkoutSessionComment? replyingTo,

  /// People picked from the mention row for the draft.
  final List<MentionCandidate> draftMentions = const [],

  /// The session's author, read when no one else names them, so they can
  /// be mentioned before they comment.
  final UserModel? sessionAuthor,
  final CommentsNotice? notice,
  final int noticeId = 0,
}) extends Equatable {
  /// Whether [comment] replies to one in the thread.
  bool isReply(WorkoutSessionComment comment) =>
      comment.parentId != null &&
      comments.any((other) => other.id == comment.parentId);

  CommentsState copyWith({
    CommentsStatus? status,
    List<WorkoutSessionComment>? comments,
    String? draft,
    WorkoutSessionComment? Function()? replyingTo,
    List<MentionCandidate>? draftMentions,
    UserModel? sessionAuthor,
    CommentsNotice? notice,
  }) => CommentsState(
    status: status ?? this.status,
    comments: comments ?? this.comments,
    draft: draft ?? this.draft,
    replyingTo: replyingTo == null ? this.replyingTo : replyingTo(),
    draftMentions: draftMentions ?? this.draftMentions,
    sessionAuthor: sessionAuthor ?? this.sessionAuthor,
    notice: notice ?? this.notice,
    noticeId: notice == null ? noticeId : noticeId + 1,
  );

  @override
  List<Object?> get props => [
    status,
    comments,
    draft,
    replyingTo,
    draftMentions,
    sessionAuthor,
    notice,
    noticeId,
  ];
}

/// One workout's comments (`CommentsPresenter`): read once, shown at once
/// when written or deleted and put back if the write fails, liked in
/// place, with replies one level deep and mentions.
class CommentsCubit extends Cubit<CommentsState> {
  new({
    required this._social,
    required this._analytics,
    required this._sessionId,
    required this._sessionAuthorId,
    this._now = DateTime.now,
    this._newId = newDocumentId,
  }) : super(const CommentsState());

  final SocialRepository _social;
  final AnalyticsRepository _analytics;
  final String _sessionId;
  final String _sessionAuthorId;
  final DateTime Function() _now;
  final String Function() _newId;

  void _track(String name, [Object? error, LogType? type]) =>
      _analytics.trackEvent(
        AnalyticsEvent(
          'CommentsView_$name',
          parameters: error == null ? null : {'error_description': '$error'},
          type: type ?? LogType.analytic,
        ),
      );

  void appeared() =>
      _analytics.trackScreenView(const AnalyticsEvent('CommentsView_Appear'));

  void disappeared() => _track('Disappear');

  /// Reads the thread, then the session's author if nobody names them.
  Future<void> load({
    required UserModel? viewer,
    required List<UserModel> following,
  }) async {
    emit(state.copyWith(status: CommentsStatus.loading));
    try {
      final comments = await _social.comments(_sessionId);
      emit(
        state.copyWith(
          status: CommentsStatus.loaded,
          comments: CommentThread.threaded(
            CommentThread.visible(comments, viewer),
          ),
        ),
      );
    } on Object catch (error) {
      _track('LoadComments_Fail', error, LogType.severe);
      emit(state.copyWith(status: CommentsStatus.failed));
    }
    final known = CommentThread.knownPeople(
      viewer: viewer,
      following: following,
      sessionAuthor: null,
      comments: state.comments,
    );
    if (viewer == null || known.any((p) => p.id == _sessionAuthorId)) return;
    // Silent: the author is only needed for mention suggestions.
    try {
      final found = await _social.users([_sessionAuthorId], viewer: viewer);
      if (found.firstOrNull case final author?) {
        emit(state.copyWith(sessionAuthor: author));
      }
    } on Object catch (error) {
      _track('LoadAuthor_Fail', error, LogType.warning);
    }
  }

  void draftChanged(String draft) => emit(state.copyWith(draft: draft));

  /// Replies stay one level deep: replying to a reply joins its thread.
  void replyPressed(WorkoutSessionComment comment) => emit(
    state.copyWith(
      replyingTo: () =>
          state.comments
              .where((other) => other.id == comment.parentId)
              .firstOrNull ??
          comment,
    ),
  );

  void cancelReplyPressed() => emit(state.copyWith(replyingTo: () => null));

  void mentionPressed(MentionCandidate candidate) => emit(
    state.copyWith(
      draft: CommentThread.insertMention(state.draft, candidate),
      draftMentions: state.draftMentions.contains(candidate)
          ? null
          : [...state.draftMentions, candidate],
    ),
  );

  /// Posts the draft as [viewer]. Shown at once and taken back, with the
  /// draft restored, if the write fails.
  Future<void> sendPressed(UserModel viewer) async {
    final text = state.draft.trim();
    if (text.isEmpty) return;
    final parent = state.replyingTo;
    final mentions = state.draftMentions;
    final comment = WorkoutSessionComment(
      id: _newId(),
      sessionId: _sessionId,
      sessionAuthorId: _sessionAuthorId,
      authorId: viewer.userId,
      authorName: fullNameOf(viewer),
      authorImageUrl: profileImageOf(viewer),
      text: text,
      dateCreated: _now(),
      parentId: parent?.id,
      mentionedUserIds: CommentThread.mentionedIds(text, mentions),
    );
    emit(
      CommentsState(
        status: state.status,
        comments: CommentThread.threaded([...state.comments, comment]),
        sessionAuthor: state.sessionAuthor,
        noticeId: state.noticeId,
      ),
    );
    _track('AddComment_Start');
    try {
      await _social.addComment(comment);
      _track('AddComment_Success');
    } on Object catch (error) {
      _track('AddComment_Fail', error, LogType.severe);
      emit(
        state.copyWith(
          comments: [
            for (final other in state.comments)
              if (other.id != comment.id) other,
          ],
          replyingTo: () => parent,
          draftMentions: mentions,
          draft: text,
          notice: CommentsNotice.postFailed,
        ),
      );
    }
  }

  /// Flips [comment]'s like for [readerId] at once, and back if it fails.
  Future<bool> likePressed(
    WorkoutSessionComment comment,
    String readerId,
  ) async {
    final current = state.comments
        .where((other) => other.id == comment.id)
        .firstOrNull;
    if (current == null) return true;
    final liking = !current.likedByUserIds.contains(readerId);
    final name = liking ? 'LikeComment' : 'UnlikeComment';
    _setLike(comment.id, readerId, liking: liking);
    _track('${name}_Start');
    try {
      await _social.setCommentLike(comment.id, userId: readerId, liked: liking);
      _track('${name}_Success');
      return true;
    } on Object catch (error) {
      _track('${name}_Fail', error, LogType.severe);
      _setLike(comment.id, readerId, liking: !liking);
      return false;
    }
  }

  void _setLike(String id, String userId, {required bool liking}) => emit(
    state.copyWith(
      comments: [
        for (final comment in state.comments)
          if (comment.id != id)
            comment
          else
            WorkoutSessionComment.fromFirestore({
              ...comment.toFirestore(),
              WorkoutSessionCommentKeys.likedByUserIds: [
                for (final liker in comment.likedByUserIds)
                  if (liker != userId) liker,
                if (liking) userId,
              ],
            }),
      ],
    ),
  );

  /// Deletes [comment] once confirmed: gone at once, back if it fails.
  Future<void> deleteConfirmed(WorkoutSessionComment comment) async {
    emit(
      state.copyWith(
        comments: [
          for (final other in state.comments)
            if (other.id != comment.id) other,
        ],
      ),
    );
    _track('DeleteComment_Start');
    try {
      await _social.deleteComment(comment.id);
      _track('DeleteComment_Success');
    } on Object catch (error) {
      _track('DeleteComment_Fail', error, LogType.severe);
      emit(
        state.copyWith(
          comments: CommentThread.threaded([...state.comments, comment]),
          notice: CommentsNotice.deleteFailed,
        ),
      );
    }
  }
}
