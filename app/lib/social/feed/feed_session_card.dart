import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/sharing/session_web_link.dart';
import 'package:compound/sharing/share_card/share_workout_card.dart';
import 'package:compound/sharing/share_card/workout_share_card.dart';
import 'package:compound/sharing/share_sheet.dart';
import 'package:compound/sharing/view/share_to_follower_page.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/feed/save_session_template_cubit.dart';
import 'package:compound/social/feed/session_like_cubit.dart';
import 'package:compound/social/report/report_cubit.dart';
import 'package:compound/social/report/report_sheet.dart';
import 'package:compound/social/social_routes.dart';
import 'package:compound/social/view/people_widgets.dart';
import 'package:compound/workout_history/workout_history.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_repository/social_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// A workout in the feed (`WorkoutSessionRowView`): who did it, the
/// workout, likes, comments, and More: Save as Template, Share with Friends
/// (the workout's template, when the reader has it), Share Image and, on
/// someone else's workout, Report. Share sends its summary and web page.
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => SessionLikeCubit(
            social: context.read<SocialRepository>(),
            analytics: context.read<AnalyticsRepository>(),
            session: session,
            viewerId: viewer?.userId,
          ),
        ),
        BlocProvider(
          create: (context) => SaveSessionTemplateCubit(
            library: context.read<TrainingLibraryRepository>(),
            analytics: context.read<AnalyticsRepository>(),
            session: session,
          ),
        ),
      ],
      child: BlocListener<SaveSessionTemplateCubit, SaveSessionTemplateState>(
        listener: _onSaveTemplate,
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
      ),
    );
  }

  void _onSaveTemplate(BuildContext context, SaveSessionTemplateState state) {
    final l10n = context.l10n;
    switch (state.status) {
      case SaveSessionTemplateStatus.saved:
        unawaited(HapticFeedback.mediumImpact());
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.programCopySaved(state.savedName!))),
          );
      case SaveSessionTemplateStatus.unresolved:
        unawaited(HapticFeedback.heavyImpact());
        unawaited(showFailureAlert(context, l10n.saveAsTemplateUnresolved));
      case SaveSessionTemplateStatus.failed:
        unawaited(HapticFeedback.heavyImpact());
        unawaited(
          showFailureAlert(
            context,
            l10n.saveAsTemplateFailed,
            l10n.socialTryAgain,
          ),
        );
      case SaveSessionTemplateStatus.idle || SaveSessionTemplateStatus.saving:
        break;
    }
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
    final like = context.watch<SessionLikeCubit>().state;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final viewer = this.viewer;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      child: Row(
        children: [
          Expanded(
            child: AppIconButton.plain(
              icon: like.isLiked ? AppSymbols.liked : AppSymbols.like,
              semanticLabel: like.isLiked ? l10n.socialUnlike : l10n.socialLike,
              label: AppFormat.number(like.count, locale: locale),
              selected: like.isLiked,
              onPressed: viewer == null
                  ? null
                  : () async {
                      final cubit = context.read<SessionLikeCubit>();
                      if (!await cubit.toggled(viewer)) {
                        unawaited(HapticFeedback.heavyImpact());
                      }
                    },
            ),
          ),
          Expanded(
            child: AppIconButton.plain(
              icon: AppSymbols.comment,
              semanticLabel: l10n.socialComments,
              onPressed: () => SocialNavigation.openComments(context, session),
            ),
          ),
          Expanded(
            child: AppIconButton.plain(
              icon: AppSymbols.share,
              semanticLabel: l10n.shareWorkout,
              onPressed: () => unawaited(_share(context)),
            ),
          ),
          Expanded(
            child: _MoreMenu(session: session, author: author, viewer: viewer),
          ),
        ],
      ),
    );
  }

  /// The workout's page, with its summary as the message; the summary
  /// alone where there is no page (`WorkoutSessionRowView`'s `ShareLink`).
  Future<void> _share(BuildContext context) {
    final link = context.read<SessionWebLink?>()?.url(session, author: author);
    final summary = shareWorkoutSummary(
      context.l10n,
      session,
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
    return context.read<ShareSheet>().shareText(
      context,
      link == null ? summary : '$summary\n$link',
    );
  }
}

/// "Push A · 5 exercises · 18 sets · 5,040 kg lifted", the volume only when
/// something was lifted, in the unit the author lifted in
/// (`WorkoutSessionRowPresenter.shareSummary`).
String shareWorkoutSummary(
  AppLocalizations l10n,
  WorkoutSessionModel session, {
  String? locale,
}) {
  final volume = session.loggedVolumeKg;
  return [
    session.name,
    l10n.exerciseCount(session.doneExercises.length),
    l10n.setCount(session.loggedSetCount),
    if (volume > 0)
      l10n.shareWorkoutLifted(
        AppFormat.weight(
          volume,
          WorkoutText.weightUnit(session.authorWeightUnit),
          locale: locale,
        ),
      ),
  ].join(' · ');
}

/// The card's More menu (`WorkoutSessionRowView`'s): Share with Friends
/// when the reader has the workout's template, their own or a built-in
/// one, and Share Image. The reader's templates are read when it opens.
class _MoreMenu extends StatefulWidget {
  const new({
    required this.session,
    required this.author,
    required this.viewer,
  });

  final WorkoutSessionModel session;
  final UserModel author;
  final UserModel? viewer;

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
    final session = widget.session;
    final viewerId = widget.viewer?.userId;
    return MenuAnchor(
      onOpen: () => unawaited(_findTemplate()),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(AppSymbols.saveAsTemplate),
          onPressed: () => unawaited(
            context.read<SaveSessionTemplateCubit>().savePressed(
              viewerId: viewerId,
              copyName: l10n.programCopyName,
            ),
          ),
          child: Text(l10n.saveAsTemplate),
        ),
        if (template != null)
          MenuItemButton(
            leadingIcon: const Icon(AppSymbols.send),
            onPressed: () => unawaited(
              showShareToFollower(context, TemplateSharePayload(template)),
            ),
            child: Text(l10n.shareWithFriends),
          ),
        shareImageSubmenu(l10n, (format) => unawaited(_shareImage(format))),
        // The reader cannot report their own workout.
        if (viewerId != null && viewerId != session.authorId)
          MenuItemButton(
            leadingIcon: const Icon(AppSymbols.report),
            onPressed: () => unawaited(
              showReportSheet(
                context,
                ReportedContent(
                  type: ReportContentType.session,
                  id: session.id,
                  authorId: session.authorId,
                ),
              ),
            ),
            child: Text(l10n.reportWorkoutMenu),
          ),
      ],
      builder: (context, controller, _) => _rendering
          ? Center(
              child: SizedBox.square(
                dimension: AppIconSize.small.of(context),
                child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
            )
          : AppIconButton.plain(
              icon: AppSymbols.more,
              semanticLabel: l10n.socialMoreActions,
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
    );
  }
}
