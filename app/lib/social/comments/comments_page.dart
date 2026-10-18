import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/comments/comment_thread.dart';
import 'package:compound/social/comments/comments_cubit.dart';
import 'package:compound/social/report/report_cubit.dart';
import 'package:compound/social/report/report_sheet.dart';
import 'package:compound/social/view/people_widgets.dart';
import 'package:compound/widgets/relative_time.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_repository/social_repository.dart';

/// A workout's comments (Swift `CommentsView`), pushed from a feed card.
class CommentsPage extends StatelessWidget {
  const new({required this.sessionId, required this.authorId, super.key});

  /// Under the workout: `/sessions/:authorId/:sessionId/comments`.
  static const path = 'comments';

  /// The route name.
  static const name = 'sessionComments';

  final String sessionId;
  final String authorId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final circle = context.read<CircleBloc>().state;
        final cubit = CommentsCubit(
          social: context.read<SocialRepository>(),
          analytics: context.read<AnalyticsRepository>(),
          sessionId: sessionId,
          sessionAuthorId: authorId,
        )..appeared();
        unawaited(
          cubit.load(viewer: circle.viewer, following: circle.visibleFollowing),
        );
        return cubit;
      },
      child: const CommentsView(),
    );
  }
}

class CommentsView extends StatefulWidget {
  const new({super.key});

  @override
  State<CommentsView> createState() => _CommentsViewState();
}

class _CommentsViewState extends State<CommentsView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final CommentsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<CommentsCubit>();
  }

  @override
  void dispose() {
    _cubit.disappeared();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onStateChanged(BuildContext context, CommentsState state) {
    if (_controller.text != state.draft) {
      _controller.value = TextEditingValue(
        text: state.draft,
        selection: TextSelection.collapsed(offset: state.draft.length),
      );
    }
  }

  Future<void> _showNotice(BuildContext context, CommentsState state) async {
    final l10n = context.l10n;
    unawaited(HapticFeedback.heavyImpact());
    await showAdaptiveDialog<void>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(switch (state.notice) {
          CommentsNotice.deleteFailed => l10n.commentsDeleteFailed,
          _ => l10n.commentsPostFailed,
        }),
        content: Text(l10n.socialTryAgain),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.settingsOk),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<CommentsCubit>().state;
    final circle = context.watch<CircleBloc>().state;
    final known = CommentThread.knownPeople(
      viewer: circle.viewer,
      following: circle.visibleFollowing,
      sessionAuthor: state.sessionAuthor,
      comments: state.comments,
    );
    return MultiBlocListener(
      listeners: [
        BlocListener<CommentsCubit, CommentsState>(
          listenWhen: (previous, current) => previous.draft != current.draft,
          listener: _onStateChanged,
        ),
        BlocListener<CommentsCubit, CommentsState>(
          listenWhen: (previous, current) =>
              previous.noticeId != current.noticeId,
          listener: _showNotice,
        ),
        // Reply already means "I'm about to type"; an empty thread has
        // nothing to read, so the only thing to do is write.
        BlocListener<CommentsCubit, CommentsState>(
          listenWhen: (previous, current) =>
              (current.replyingTo != null &&
                  previous.replyingTo != current.replyingTo) ||
              (previous.status == CommentsStatus.loading &&
                  current.status == CommentsStatus.loaded &&
                  current.comments.isEmpty),
          listener: (_, _) => _focus.requestFocus(),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.socialComments)),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: switch (state.status) {
                  CommentsStatus.loading => const Center(
                    child: CircularProgressIndicator.adaptive(),
                  ),
                  CommentsStatus.failed => Center(
                    child: SingleChildScrollView(
                      child: SocialEmptyState(
                        icon: AppSymbols.warning,
                        title: l10n.commentsLoadFailedTitle,
                        message: l10n.commentsLoadFailedMessage,
                        action: TextButton(
                          onPressed: () => _cubit.load(
                            viewer: circle.viewer,
                            following: circle.visibleFollowing,
                          ),
                          child: Text(l10n.tryAgainButton),
                        ),
                      ),
                    ),
                  ),
                  CommentsStatus.loaded when state.comments.isEmpty => Center(
                    child: SingleChildScrollView(
                      child: SocialEmptyState(
                        icon: AppSymbols.comment,
                        title: l10n.commentsEmptyTitle,
                        message: l10n.commentsEmptyMessage,
                      ),
                    ),
                  ),
                  CommentsStatus.loaded => ListView(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                    children: [
                      for (final comment in state.comments)
                        _CommentRow(
                          comment: comment,
                          isReply: state.isReply(comment),
                          known: known,
                          viewerId: circle.viewer?.userId,
                        ),
                    ],
                  ),
                },
              ),
              _InputBar(
                controller: _controller,
                focus: _focus,
                suggestions: CommentThread.suggestions(
                  state.draft,
                  known,
                  readerId: circle.viewer?.userId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const new({
    required this.comment,
    required this.isReply,
    required this.known,
    required this.viewerId,
  });

  final WorkoutSessionComment comment;
  final bool isReply;
  final List<MentionCandidate> known;
  final String? viewerId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final cubit = context.read<CommentsCubit>();
    final viewerId = this.viewerId;
    final isOwn = comment.authorId == viewerId;
    final isLiked = comment.likedByUserIds.contains(viewerId);
    final likes = comment.likedByUserIds.length;
    final secondary = AppTextStyles.label.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final ranges = CommentThread.mentionRanges(comment, known);
    var cursor = 0;
    final spans = <TextSpan>[];
    for (final (start, end) in ranges) {
      spans
        ..add(TextSpan(text: comment.text.substring(cursor, start)))
        ..add(
          TextSpan(
            text: comment.text.substring(start, end),
            style: TextStyle(color: scheme.primary),
          ),
        );
      cursor = end;
    }
    spans.add(TextSpan(text: comment.text.substring(cursor)));
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.l + (isReply ? AppControlSize.thumbnail : 0),
        AppSpacing.s,
        AppSpacing.s,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.s,
        children: [
          UserAvatar(
            imageUrl: comment.authorImageUrl,
            size: AppControlSize.thumbnail,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: [
                Row(
                  spacing: AppSpacing.s,
                  children: [
                    Expanded(
                      child: Text(
                        comment.authorName ?? l10n.socialUnknown,
                        style: AppTextStyles.rowDetail.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    RelativeTimeBuilder(
                      date: comment.dateCreated,
                      builder: (context, text) => Text(text, style: secondary),
                    ),
                  ],
                ),
                Text.rich(
                  TextSpan(children: spans),
                  style: AppTextStyles.rowDetail,
                ),
                Row(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onSurfaceVariant,
                        textStyle: AppTextStyles.label,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(
                          AppControlSize.row,
                          AppControlSize.row,
                        ),
                      ),
                      onPressed: () => cubit.replyPressed(comment),
                      child: Text(l10n.commentsReply),
                    ),
                    if (isOwn) ...[
                      const SizedBox(width: AppSpacing.m),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: context.appColors.danger,
                          textStyle: AppTextStyles.label,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(
                            AppControlSize.row,
                            AppControlSize.row,
                          ),
                        ),
                        onPressed: () => _confirmDelete(context),
                        child: Text(l10n.commentsDelete),
                      ),
                    ] else if (viewerId != null) ...[
                      const SizedBox(width: AppSpacing.m),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.onSurfaceVariant,
                          textStyle: AppTextStyles.label,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(
                            AppControlSize.row,
                            AppControlSize.row,
                          ),
                        ),
                        onPressed: () => unawaited(
                          showReportSheet(
                            context,
                            ReportedContent(
                              type: ReportContentType.comment,
                              id: comment.id,
                              authorId: comment.authorId,
                            ),
                          ),
                        ),
                        child: Text(l10n.reportCommentAction),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Semantics(
            label: isLiked ? l10n.commentsUnlike : l10n.commentsLike,
            value: l10n.socialLikes(likes),
            button: true,
            excludeSemantics: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: viewerId == null
                  ? null
                  : () async {
                      if (!await cubit.likePressed(comment, viewerId)) {
                        unawaited(HapticFeedback.heavyImpact());
                      }
                    },
              child: SizedBox(
                width: AppControlSize.row,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                  child: Column(
                    children: [
                      Icon(
                        isLiked ? AppSymbols.heartFilled : AppSymbols.heart,
                        color: isLiked
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        size: AppIconSize.small.of(context),
                      ),
                      if (likes > 0)
                        Text(
                          AppFormat.number(likes, locale: locale),
                          style: secondary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<CommentsCubit>();
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(l10n.commentsDeleteTitle),
        content: Text(l10n.commentsDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commentsCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.danger,
            ),
            child: Text(l10n.commentsDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.deleteConfirmed(comment);
  }
}

class _InputBar extends StatelessWidget {
  const new({
    required this.controller,
    required this.focus,
    required this.suggestions,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final List<MentionCandidate> suggestions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<CommentsCubit>();
    final state = context.watch<CommentsCubit>().state;
    final viewer = context.select<CircleBloc, UserModel?>(
      (bloc) => bloc.state.viewer,
    );
    final parent = state.replyingTo;
    final canSend = state.draft.trim().isNotEmpty && viewer != null;
    return Material(
      color: context.appColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.s,
          AppSpacing.s,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (parent != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.commentsReplyingTo(
                        parent.authorName ?? l10n.commentsCommentFallback,
                      ),
                      style: AppTextStyles.label.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commentsCancelReply,
                    onPressed: cubit.cancelReplyPressed,
                    icon: const Icon(AppSymbols.close),
                  ),
                ],
              ),
            if (suggestions.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: AppSpacing.s,
                  children: [
                    for (final candidate in suggestions)
                      Semantics(
                        label: l10n.commentsMention(candidate.fullName),
                        button: true,
                        excludeSemantics: true,
                        child: OutlinedButton(
                          onPressed: () => cubit.mentionPressed(candidate),
                          child: Text(candidate.label),
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focus,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: parent == null
                          ? l10n.commentsAddComment
                          : l10n.commentsAddReply,
                      border: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: cubit.draftChanged,
                  ),
                ),
                IconButton(
                  tooltip: l10n.commentsSend,
                  color: scheme.primary,
                  onPressed: canSend
                      ? () async {
                          await cubit.sendPressed(viewer);
                          unawaited(HapticFeedback.lightImpact());
                        }
                      : null,
                  icon: const Icon(AppSymbols.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
