import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/challenges/cubit/challenge_detail_cubit.dart';
import 'package:compound/challenges/cubit/challenges_cubit.dart';
import 'package:compound/challenges/logic/challenge_standings.dart';
import 'package:compound/challenges/view/challenge_ring.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/social_routes.dart';
import 'package:compound/social/view/people_widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:social_repository/social_repository.dart';

/// A challenge's standings (`ChallengeDetailView`): the reader's ring, the
/// target and dates, every member ranked, and Leave Challenge for a member.
class ChallengeDetailPage extends StatelessWidget {
  const new({required this.challengeId, this.challenge, super.key});

  /// The route's path, over the tabs.
  static const path = '/challenges/:$idParameter';

  /// The route's name.
  static const name = 'challengeDetail';

  /// The path parameter naming the challenge.
  static const idParameter = 'challengeId';

  final String challengeId;

  /// The challenge, when the caller has it; read by id otherwise.
  final ChallengeModel? challenge;

  @override
  Widget build(BuildContext context) {
    // Built once the circle knows who is signed in, which a link opened at
    // launch can beat.
    context.select<CircleBloc, bool>((bloc) => bloc.state.viewer != null);
    final circle = context.read<CircleBloc>().state;
    final viewer = circle.viewer;
    if (viewer == null) return const SizedBox.shrink();
    final held = context.read<ChallengesCubit>().state;
    return BlocProvider(
      create: (context) {
        final cubit = ChallengeDetailCubit(
          social: context.read<SocialRepository>(),
          analytics: context.read<AnalyticsRepository>(),
          viewer: viewer,
          challengeId: challengeId,
          following: circle.followingUsers,
          challenge: held.challenge(challengeId) ?? challenge,
          progress: held.progress[challengeId] ?? const {},
        )..appeared();
        unawaited(cubit.load());
        return cubit;
      },
      child: ChallengeDetailView(viewerId: viewer.userId),
    );
  }
}

class ChallengeDetailView extends StatefulWidget {
  const new({required this.viewerId, super.key});

  final String viewerId;

  @override
  State<ChallengeDetailView> createState() => _ChallengeDetailViewState();
}

class _ChallengeDetailViewState extends State<ChallengeDetailView> {
  late final ChallengeDetailCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read();
  }

  @override
  void dispose() {
    _cubit.disappeared();
    super.dispose();
  }

  Future<void> _confirmLeave(ChallengeModel challenge) async {
    final l10n = context.l10n;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.challengeLeaveTitle(challenge.title)),
        content: Text(l10n.challengeLeaveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commentsCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.challengeLeave),
          ),
        ],
      ),
    );
    if (leave ?? false) await _cubit.leave();
  }

  void _onLeave(BuildContext context, ChallengeDetailState state) {
    if (state.leaveStatus == ChallengeLeaveStatus.left) {
      context.read<ChallengesCubit>().left(state.challenge!.id);
      context.pop();
    } else if (state.leaveStatus == ChallengeLeaveStatus.failed) {
      final l10n = context.l10n;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.challengeLeaveFailed}. ${l10n.socialTryAgain}',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ChallengeDetailCubit>().state;
    // The held copy carries member edits; the one opened with otherwise.
    final challenge =
        context.select<ChallengesCubit, ChallengeModel?>(
          (cubit) => cubit.state.challenge(state.challenge?.id ?? ''),
        ) ??
        state.challenge;
    final isMember = challenge?.memberIds.contains(widget.viewerId) ?? false;
    return MultiBlocListener(
      listeners: [
        BlocListener<ChallengeDetailCubit, ChallengeDetailState>(
          listenWhen: (previous, current) =>
              previous.leaveStatus != current.leaveStatus ||
              previous.failureId != current.failureId,
          listener: _onLeave,
        ),
        // Social's card shows the counts just read.
        BlocListener<ChallengeDetailCubit, ChallengeDetailState>(
          listenWhen: (previous, current) =>
              previous.progress != current.progress &&
              current.challenge != null,
          listener: (context, state) => context
              .read<ChallengesCubit>()
              .progressRead(state.challenge!.id, state.progress),
        ),
      ],
      child: AppScaffold(
        appBar: AppBar(
          title: Text(challenge?.title ?? ''),
          actions: [
            if (challenge != null && isMember)
              PopupMenuButton<void>(
                tooltip: l10n.socialMoreActions,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: () => unawaited(_confirmLeave(challenge)),
                    child: ListTile(
                      leading: Icon(
                        AppSymbols.leave,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(l10n.challengeLeaveMenu),
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: switch ((challenge, state.notFound)) {
          (_, true) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: AppInlineMessage(
                kind: AppInlineMessageKind.error,
                text: l10n.challengeNotFound,
                kindLabel: l10n.errorLabel,
              ),
            ),
          ),
          (null, _) => const Center(
            child: CircularProgressIndicator.adaptive(),
          ),
          (final ChallengeModel challenge, _) => _Standings(
            challenge: challenge,
            state: state,
            viewerId: widget.viewerId,
          ),
        },
      ),
    );
  }
}

class _Standings extends StatelessWidget {
  const new({
    required this.challenge,
    required this.state,
    required this.viewerId,
  });

  final ChallengeModel challenge;
  final ChallengeDetailState state;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    final dates = DateFormat.yMMMd(locale);
    final daysLeft = ChallengeStandings.daysLeft(challenge, DateTime.now());
    final mySessions = state.progress[viewerId] ?? 0;
    final standings = state.standings(challenge);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Row(
              spacing: AppSpacing.l,
              children: [
                ChallengeRing(
                  sessions: mySessions,
                  target: challenge.targetSessions,
                  size: 88,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.xs,
                    children: [
                      Text(
                        l10n.challengeTrainTimes(challenge.targetSessions),
                        style: AppTextStyles.sectionTitle,
                      ),
                      Text(
                        daysLeft == 0
                            ? l10n.challengeEnded
                            : l10n.challengeDaysLeft(daysLeft),
                        style: AppTextStyles.rowDetail.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${dates.format(challenge.startsAt.toLocal())} – '
                        '${dates.format(challenge.endsAt.toLocal())}',
                        style: AppTextStyles.label.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSection(
          header: l10n.challengeStandings,
          children: [
            for (final (index, entry) in standings.indexed)
              _StandingRow(
                entry: entry,
                rank: index + 1,
                target: challenge.targetSessions,
                isOwn: entry.userId == viewerId,
                onPressed: switch (state.users[entry.userId]) {
                  final user? => () => SocialNavigation.openProfile(
                    context,
                    user,
                  ),
                  null => null,
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  const new({
    required this.entry,
    required this.rank,
    required this.target,
    required this.isOwn,
    required this.onPressed,
  });

  final ChallengeStanding entry;
  final int rank;
  final int target;
  final bool isOwn;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final name = isOwn ? l10n.socialYou : entry.name ?? l10n.challengeMember;
    return Semantics(
      button: onPressed != null,
      label: l10n.challengeRowLabel(rank, name, entry.sessions, target),
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.s,
          ),
          child: Row(
            spacing: AppSpacing.m,
            children: [
              SizedBox(
                width: MediaQuery.textScalerOf(context).scale(24),
                child: Text(
                  AppFormat.number(rank, locale: locale),
                  style: AppTextStyles.rowDetail.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              UserAvatar(
                imageUrl: entry.imageUrl,
                size: AppControlSize.thumbnail,
              ),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.rowTitle.copyWith(
                    fontWeight: isOwn ? FontWeight.w600 : null,
                  ),
                ),
              ),
              if (entry.isComplete)
                Icon(
                  AppSymbols.success,
                  color: context.appColors.success,
                  semanticLabel: l10n.challengeFinished,
                ),
              Text(
                '${entry.sessions}/$target',
                style: AppTextStyles.metricSmall.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
