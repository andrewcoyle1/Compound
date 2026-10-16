import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/sharing/share_card/share_workout_card.dart';
import 'package:compound/sharing/share_card/workout_share_card.dart';
import 'package:compound/sharing/view/share_to_follower_page.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/feed/session_like_cubit.dart';
import 'package:compound/social/social_routes.dart';
import 'package:compound/social/view/people_widgets.dart';
import 'package:compound/workout_history/workout_history.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_repository/social_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// A workout in the feed (`WorkoutSessionRowView`): who did it, the
/// workout, likes, comments, and More: Share with Friends (the workout's
/// template, when the reader has it) and Share Image. The text share with
/// the web link, Save as Template and Report are not ported yet.
class FeedSessionCard extends StatelessWidget {
  const new({
    required this.entry,
    required this.author,
    required this.viewer,
    super.key,
  });

  /// The workout and its highlights.
  final WorkoutHistoryEntry entry;

  /// Who did it.
  final UserModel author;

  /// The signed-in user.
  final UserModel? viewer;

  @override
  Widget build(BuildContext context) {
    final session = entry.session;
    return BlocProvider(
      create: (context) => SessionLikeCubit(
        social: context.read<SocialRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        session: session,
        viewerId: viewer?.userId,
      ),
      child: WorkoutSessionCard(
        entry: entry,
        header: AuthorHeader(
          author: author,
          date: session.dateCreated,
          onPressed: () => SocialNavigation.openProfile(context, author),
        ),
        onPressed: () => SocialNavigation.openSession(context, session),
        // A note is its author's private reminder, not a caption.
        showsNote: viewer?.userId == session.authorId,
        footer: _Actions(session: session, author: author, viewer: viewer),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const new({
    required this.session,
    required this.author,
    required this.viewer,
  });

  final WorkoutSessionModel session;
  final UserModel author;
  final UserModel? viewer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final like = context.watch<SessionLikeCubit>().state;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final viewer = this.viewer;
    final style = TextButton.styleFrom(
      foregroundColor: scheme.onSurfaceVariant,
      minimumSize: const Size.fromHeight(AppControlSize.row),
      textStyle: AppTextStyles.rowDetail,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: like.isLiked ? l10n.socialUnlike : l10n.socialLike,
              value: l10n.socialLikes(like.count),
              button: true,
              excludeSemantics: true,
              child: TextButton.icon(
                style: style.copyWith(
                  foregroundColor: WidgetStatePropertyAll(
                    like.isLiked ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                onPressed: viewer == null
                    ? null
                    : () async {
                        final cubit = context.read<SessionLikeCubit>();
                        if (!await cubit.toggled(viewer)) {
                          unawaited(HapticFeedback.heavyImpact());
                        }
                      },
                icon: Icon(like.isLiked ? AppSymbols.liked : AppSymbols.like),
                label: Text(AppFormat.number(like.count, locale: locale)),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              label: l10n.socialComments,
              button: true,
              excludeSemantics: true,
              child: TextButton(
                style: style,
                onPressed: () =>
                    SocialNavigation.openComments(context, session),
                child: const Icon(AppSymbols.comment),
              ),
            ),
          ),
          Expanded(
            child: _MoreMenu(
              session: session,
              author: author,
              viewer: viewer,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// The card's More menu (`WorkoutSessionRowView`'s): Share with Friends
/// when the reader has the workout's template, their own or a built-in
/// one, and Share Image. The reader's templates are read when it opens.
class _MoreMenu extends StatefulWidget {
  const new({
    required this.session,
    required this.author,
    required this.viewer,
    required this.style,
  });

  final WorkoutSessionModel session;
  final UserModel author;
  final UserModel? viewer;
  final ButtonStyle style;

  @override
  State<_MoreMenu> createState() => _MoreMenuState();
}

class _MoreMenuState extends State<_MoreMenu> {
  WorkoutTemplateModel? _template;
  bool _rendering = false;

  /// The template the session was started from, when the reader has it
  /// (`WorkoutSessionRowPresenter.shareableTemplate`).
  Future<void> _findTemplate() async {
    final id = widget.session.workoutTemplateId;
    final viewer = widget.viewer;
    if (id == null || viewer == null || _template != null) return;
    final library = context.read<TrainingLibraryRepository>();
    final builtIn = PrebuiltCatalogue.instance.workoutTemplates.where(
      (template) => template.workoutId == id,
    );
    final found =
        builtIn.firstOrNull ??
        (await library.watchUserWorkoutTemplates(viewer.userId).first)
            .where((template) => template.workoutId == id)
            .firstOrNull;
    if (mounted && found != null) setState(() => _template = found);
  }

  Future<void> _shareImage(ShareCardFormat format) async {
    final circle = context.read<CircleBloc>().state;
    final session = widget.session;
    setState(() => _rendering = true);
    await shareWorkoutCard(
      context,
      session,
      author: widget.author,
      history: [
        for (final other in circle.sessions)
          if (other.authorId == session.authorId) other,
      ],
      format: format,
      eventPrefix: 'WorkoutSessionRow',
    );
    if (mounted) setState(() => _rendering = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final template = _template;
    return MenuAnchor(
      onOpen: () => unawaited(_findTemplate()),
      menuChildren: [
        if (template != null)
          MenuItemButton(
            leadingIcon: const Icon(AppSymbols.send),
            onPressed: () => unawaited(
              showShareToFollower(context, TemplateSharePayload(template)),
            ),
            child: Text(l10n.shareWithFriends),
          ),
        shareImageSubmenu(l10n, (format) => unawaited(_shareImage(format))),
      ],
      builder: (context, controller, _) => TextButton(
        style: widget.style,
        onPressed: _rendering
            ? null
            : () => controller.isOpen ? controller.close() : controller.open(),
        child: _rendering
            ? const SizedBox.square(
                dimension: AppSpacing.l,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            : Icon(AppSymbols.more, semanticLabel: l10n.socialMoreActions),
      ),
    );
  }
}
