import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/social/feed/session_like_cubit.dart';
import 'package:compound/social/social_routes.dart';
import 'package:compound/social/view/people_widgets.dart';
import 'package:compound/workout_history/workout_history.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_repository/social_repository.dart';

/// A workout in the feed (`WorkoutSessionRowView`): who did it, the
/// workout, and likes and comments. Share, Save as Template and Report are
/// not ported yet.
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
        footer: _Actions(session: session, viewer: viewer),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const new({required this.session, required this.viewer});

  final WorkoutSessionModel session;
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
        ],
      ),
    );
  }
}
