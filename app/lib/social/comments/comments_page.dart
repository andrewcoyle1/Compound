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
    await showAppDialog<void>(
      context: context,
      title: switch (state.notice) {
        CommentsNotice.deleteFailed => l10n.commentsDeleteFailed,
        _ => l10n.commentsPostFailed,
      },
      message: l10n.socialTryAgain,
      actions: [AppDialogAction(label: l10n.settingsOk)],
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
      child: AppScaffold(
        appBar: AppBar(title: Text(l10n.socialComments)),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: switch (state.status) {
                  CommentsStatus.loading => AppLoadingView(
                    label: l10n.launchLoading,
                  ),
                  CommentsStatus.failed => AppErrorState(
                    title: l10n.commentsLoadFailedTitle,
                    description: l10n.commentsLoadFailedMessage,
                    actionLabel: l10n.tryAgainButton,
                    onAction: () => _cubit.load(
                      viewer: circle.viewer,
                      following: circle.visibleFollowing,
                    ),
                  ),
                  CommentsStatus.loaded when state.comments.isEmpty =>
                    AppEmptyState(
                      icon: AppSymbols.comment,
                      title: l10n.commentsEmptyTitle,
                      description: l10n.commentsEmptyMessage,
                    ),
                  CommentsStatus.loaded => ListView(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    children: [
                      AppSection(
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
            style: AppTextStyles.rowDetail.copyWith(color: scheme.primary),
          ),
        );
      cursor = end;
    }
    spans.add(TextSpan(text: comment.text.substring(cursor)));
    void report() => unawaited(
      showReportSheet(
        context,
        ReportedContent(
          type: ReportContentType.comment,
          id: comment.id,
          authorId: comment.authorId,
        ),
      ),
    );
    // Swift's swipe actions: Reply leading; Delete on one's own comment,
    // else Report, trailing. The row's buttons do the same.
    return AppSwipeActions(
      leading: [
        AppSwipeAction(
          label: l10n.commentsReply,
          icon: AppSymbols.reply,
          tint: scheme.primary,
          onPressed: () => cubit.replyPressed(comment),
        ),
      ],
      trailing: [
        if (isOwn)
          AppSwipeAction(
            label: l10n.commentsDelete,
            icon: AppSymbols.delete,
            isDestructive: true,
            onPressed: () => unawaited(_confirmDelete(context)),
          )
        else if (viewerId != null)
          AppSwipeAction(
            label: l10n.reportCommentAction,
            icon: AppSymbols.report,
            tint: context.appColors.warning,
            onPressed: report,
          ),
      ],
      child: Padding(
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
                  // The time wraps under a long name rather than squeezing
                  // it, at large text sizes.
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: AppSpacing.s,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          comment.authorName ?? l10n.socialUnknown,
                          style: AppTextStyles.sectionTitle,
                        ),
                        RelativeTimeBuilder(
                          date: comment.dateCreated,
                          builder: (context, text) =>
                              Text(text, style: secondary),
                        ),
                      ],
                    ),
                  ),
                  Text.rich(
                    TextSpan(children: spans),
                    style: AppTextStyles.rowDetail,
                  ),
                  // Pulled back by the buttons' own padding, so the first
                  // label lines up with the comment.
                  Transform.translate(
                    offset: const Offset(-AppSpacing.s, 0),
                    child: Wrap(
                      children: [
                        AppTextButton(
                          label: l10n.commentsReply,
                          onPressed: () => cubit.replyPressed(comment),
                        ),
                        if (isOwn)
                          AppTextButton(
                            label: l10n.commentsDelete,
                            isDestructive: true,
                            onPressed: () => _confirmDelete(context),
                          )
                        else if (viewerId != null)
                          AppTextButton(
                            label: l10n.reportCommentAction,
                            onPressed: report,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppIconButton.plain(
              icon: isLiked ? AppSymbols.heartFilled : AppSymbols.heart,
              semanticLabel: isLiked ? l10n.commentsUnlike : l10n.commentsLike,
              label: likes > 0 ? AppFormat.number(likes, locale: locale) : null,
              selected: isLiked,
              onPressed: viewerId == null
                  ? null
                  : () async {
                      if (!await cubit.likePressed(comment, viewerId)) {
                        unawaited(HapticFeedback.heavyImpact());
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<CommentsCubit>();
    final confirmed = await AppDialog.confirmDestructive(
      context,
      title: l10n.commentsDeleteTitle,
      message: l10n.commentsDeleteMessage,
      confirmLabel: l10n.commentsDelete,
      cancelLabel: l10n.commentsCancel,
    );
    if (confirmed) await cubit.deleteConfirmed(comment);
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
    // A floating card under the thread, as Swift's composer capsule.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.s,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.xs,
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
                    AppIconButton.plain(
                      icon: AppSymbols.close,
                      semanticLabel: l10n.commentsCancelReply,
                      onPressed: cubit.cancelReplyPressed,
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
                          child: AppChip(
                            label: candidate.label,
                            onPressed: () => cubit.mentionPressed(candidate),
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
                  AppIconButton(
                    icon: AppSymbols.send,
                    semanticLabel: l10n.commentsSend,
                    onPressed: canSend
                        ? () async {
                            await cubit.sendPressed(viewer);
                            unawaited(HapticFeedback.lightImpact());
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
