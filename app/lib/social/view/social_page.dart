import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/challenges/challenges.dart';
import 'package:compound/l10n/first_weekday.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/notifications/inbox/inbox_bloc.dart';
import 'package:compound/notifications/inbox/view/notifications_page.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/feed/feed_entry.dart';
import 'package:compound/social/feed/feed_session_card.dart';
import 'package:compound/social/invite/invite_code_sheet.dart';
import 'package:compound/social/invite/invite_cubit.dart';
import 'package:compound/social/logic/circle_week.dart';
import 'package:compound/social/logic/people.dart';
import 'package:compound/social/search/people_search_bloc.dart';
import 'package:compound/social/search/social_cubit.dart';
import 'package:compound/social/social_routes.dart';
import 'package:compound/social/view/circle_strip.dart';
import 'package:compound/social/view/people_widgets.dart';
import 'package:compound/social/weekly_goal/weekly_goal_sheet.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_repository/social_repository.dart';

/// The Social tab (Swift `SocialView`): the circle strip, the week's
/// leaderboard and the following feed, with a search for people, and the
/// notifications bell, the circle's challenges, and invites.
class SocialPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => SocialCubit(
            social: context.read<SocialRepository>(),
            analytics: context.read<AnalyticsRepository>(),
          )..appeared(),
        ),
        BlocProvider(
          create: (context) =>
              PeopleSearchBloc(social: context.read<SocialRepository>()),
        ),
      ],
      child: const SocialView(),
    );
  }
}

class SocialView extends StatefulWidget {
  const new({super.key});

  @override
  State<SocialView> createState() => _SocialViewState();
}

class _SocialViewState extends State<SocialView> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  late final SocialCubit _cubit;
  bool _suggestionsRequested = false;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<SocialCubit>();
    // The bell's badge, refreshed silently.
    context.read<InboxBloc>().add(const InboxBadgeRefreshRequested());
    unawaited(context.read<ChallengesCubit>().refresh());
    _searchFocus.addListener(() => setState(() {}));
    _maybeLoadSuggestions(context.read<CircleBloc>().state);
  }

  @override
  void dispose() {
    _cubit.disappeared();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Suggestions are only for an empty feed, once it has loaded.
  void _maybeLoadSuggestions(CircleState circle) {
    final viewer = circle.viewer;
    if (_suggestionsRequested ||
        viewer == null ||
        circle.isFeedLoading ||
        circle.feed.isNotEmpty) {
      return;
    }
    _suggestionsRequested = true;
    unawaited(_cubit.loadSuggestions(viewer));
  }

  void _findPeople() {
    _cubit.pressed('FindPeople_Press');
    _searchFocus.requestFocus();
  }

  void _queryChanged(String query) {
    final viewer = context.read<CircleBloc>().state.viewer;
    if (viewer == null) return;
    context.read<PeopleSearchBloc>().add(
      PeopleSearchQueryChanged(query, viewer),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSearching = _searchFocus.hasFocus || _search.text.isNotEmpty;
    return BlocListener<CircleBloc, CircleState>(
      listenWhen: (previous, current) =>
          previous.isFeedLoading != current.isFeedLoading,
      listener: (_, circle) => _maybeLoadSuggestions(circle),
      child: AppScaffold(
        largeTitle: l10n.tabSocial,
        actions: const [_NotificationsButton(), ProfileButton()],
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  0,
                  AppSpacing.l,
                  AppSpacing.s,
                ),
                child: AppSearchField(
                  controller: _search,
                  focusNode: _searchFocus,
                  hint: l10n.socialSearchPrompt,
                  clearLabel: l10n.commentsCancel,
                  onChanged: _queryChanged,
                ),
              ),
              Expanded(
                child: isSearching
                    ? const _SearchResults()
                    : _Dashboard(onFindPeople: _findPeople),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final search = context.watch<PeopleSearchBloc>().state;
    final circle = context.watch<CircleBloc>().state;
    if (!search.isSearching) {
      final viewer = circle.viewer;
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppSection(
            footer: l10n.inviteSearchFooter,
            children: [
              AppListRowButton(
                title: l10n.inviteFriendRow,
                icon: AppSymbols.share,
                accessory: null,
                onPressed: viewer == null
                    ? null
                    : () => unawaited(
                        context.read<InviteCubit>().shareRequested(
                          viewer.userId,
                          pressedEvent: 'SocialView_InviteFriend_Press',
                        ),
                      ),
              ),
              AppListRowButton(
                title: l10n.inviteEnterCode,
                icon: AppSymbols.invite,
                accessory: null,
                onPressed: viewer == null
                    ? null
                    : () async {
                        final invites = context.read<InviteCubit>();
                        final code = await showInviteCodeSheet(context);
                        if (code == null) return;
                        await invites.accept(code, viewer: viewer);
                      },
              ),
            ],
          ),
        ],
      );
    }
    final results = search.results(circle.visibleFollowing);
    if (results.isEmpty && !search.isLoading && !search.failed) {
      return AppEmptyState(
        icon: AppSymbols.search,
        title: l10n.socialNoResults(search.query.trim()),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        if (search.failed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.l),
            child: AppInlineMessage(
              kind: AppInlineMessageKind.warning,
              text: l10n.socialSearchFailed,
              kindLabel: l10n.errorLabel,
            ),
          ),
        AppSection(
          header: l10n.socialPeople,
          children: [
            if (search.isLoading && results.isEmpty)
              for (var i = 0; i < 3; i++)
                AppPlaceholderRow(
                  hasLeading: true,
                  semanticLabel: i == 0 ? l10n.launchLoading : null,
                ),
            for (final user in results)
              UserRow(
                user: user,
                onPressed: () {
                  context.read<SocialCubit>().pressed('SearchResult_Press');
                  SocialNavigation.openProfile(context, user);
                },
                trailing: FollowButton(
                  state: circle.followState(user.userId),
                  onPressed: () =>
                      context.read<CircleBloc>().add(CircleFollowPressed(user)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Dashboard extends StatelessWidget {
  const new({required this.onFindPeople});

  final VoidCallback onFindPeople;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final circle = context.watch<CircleBloc>().state;
    final cubit = context.read<SocialCubit>();
    final viewer = circle.viewer;
    if (viewer == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final firstDay = firstDayOfWeekIndex(context);
    final members = circle.members(now: now, firstDayOfWeek: firstDay);
    final summary = members.isEmpty
        ? null
        : CircleWeek.summary(
            reader: viewer,
            circle: [for (final member in members) member.user],
            sessions: circle.sessions,
            now: now,
            firstDayOfWeek: firstDay,
            dismissedWeek: circle.dismissedSummaryWeek,
          );
    final feed = circle.feed;
    final held = context.watch<ChallengesCubit>().state;
    final challenges = challengeCards(
      held.challenges,
      progress: held.progress,
      users: {
        for (final user in circle.followingUsers) user.userId: user,
        viewer.userId: viewer,
      },
      readerId: viewer.userId,
      now: now,
    );
    final sessions = circle.sessions;
    final suggestions = [
      for (final user in context.watch<SocialCubit>().state)
        if (!(viewer.followingIds?.contains(user.userId) ?? false)) user,
    ];
    const gutter = EdgeInsets.fromLTRB(
      AppSpacing.l,
      0,
      AppSpacing.l,
      AppSpacing.m,
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        if (members.isNotEmpty)
          CircleStrip(
            members: members,
            onMemberPressed: (member) {
              cubit.pressed('CircleMember_Press');
              SocialNavigation.openProfile(context, member.user);
            },
            onNudgePressed: (member) {
              unawaited(AppHaptics.light());
              context.read<CircleBloc>().add(CircleNudgePressed(member));
            },
            onSetGoalPressed: viewer.weeklySessionGoal == null
                ? () {
                    cubit.pressed('SetWeeklyGoal_Press');
                    unawaited(showWeeklyGoalSheet(context, viewer));
                  }
                : null,
          ),
        if (viewer.username == null && !circle.usernameBannerDismissed)
          Padding(
            padding: gutter,
            child: _Banner(
              icon: AppSymbols.username,
              iconColor: context.appColors.accentInk,
              text: l10n.socialPickUsername,
              dismissLabel: l10n.socialDismiss,
              onPressed: () {
                cubit.pressed('PickUsername_Press');
                SocialNavigation.openUsername(context);
              },
              onDismissed: () => context.read<CircleBloc>().add(
                const CircleUsernameBannerDismissed(),
              ),
            ),
          ),
        if (summary != null)
          Padding(
            padding: gutter,
            child: _Banner(
              icon: AppSymbols.streak,
              iconColor: context.appColors.accentInk,
              text: l10n.socialWeeklySummary(
                summary.circleSessions,
                summary.ownSessions,
                summary.ownGoal,
              ),
              dismissLabel: l10n.socialDismissSummary,
              onDismissed: () => context.read<CircleBloc>().add(
                CircleWeeklySummaryDismissed(summary.weekStart),
              ),
            ),
          ),
        if (circle.showsInviteCard)
          Padding(
            padding: gutter,
            child: _Banner(
              icon: AppSymbols.invite,
              iconColor: context.appColors.accentInk,
              text: l10n.inviteCardTitle,
              detail: l10n.inviteCardMessage,
              dismissLabel: l10n.socialDismiss,
              onPressed: () {
                context.read<CircleBloc>().add(
                  const CircleInviteCardDismissed(),
                );
                unawaited(
                  context.read<InviteCubit>().shareRequested(
                    viewer.userId,
                    pressedEvent: 'SocialView_InviteCard_Press',
                  ),
                );
              },
              onDismissed: () {
                cubit.pressed('InviteCard_Dismiss');
                context.read<CircleBloc>().add(
                  const CircleInviteCardDismissed(),
                );
              },
            ),
          ),
        if (members.isNotEmpty)
          Padding(
            padding: gutter,
            child: _Leaderboard(
              standings: CircleWeek.standings(
                users: [for (final member in members) member.user],
                sessions: sessions,
                now: now,
                firstDayOfWeek: firstDay,
              ),
              viewerId: viewer.userId,
              onPressed: (user) {
                cubit.pressed('LeaderboardRow_Press');
                SocialNavigation.openProfile(context, user);
              },
            ),
          ),
        if (challenges.isNotEmpty || members.isNotEmpty)
          ChallengesSection(
            cards: challenges,
            viewerId: viewer.userId,
            onCardPressed: (card) {
              cubit.pressed('Challenge_Press');
              ChallengeNavigation.open(context, card.challenge);
            },
            onCreatePressed: () {
              cubit.pressed('CreateChallenge_Press');
              ChallengeNavigation.openNew(context);
            },
          ),
        Padding(
          padding: gutter,
          child: AppSection(
            header: l10n.socialWorkoutFeed,
            trailing: feed.isEmpty
                ? null
                : AppChip(
                    label: l10n.socialFindPeople,
                    onPressed: onFindPeople,
                  ),
            grouped: false,
            children: [
              if (circle.isFeedLoading)
                AppCard(
                  child: Column(
                    children: [
                      AppPlaceholderRow(
                        hasLeading: true,
                        semanticLabel: l10n.launchLoading,
                      ),
                      const AppPlaceholderRow(),
                    ],
                  ),
                )
              else if (feed.isEmpty)
                AppEmptyState(
                  icon: AppSymbols.friends,
                  title: l10n.socialNoActivityTitle,
                  description: l10n.socialNoActivityMessage,
                  actionLabel: l10n.socialFindPeople,
                  onAction: onFindPeople,
                )
              else
                for (final session in feed)
                  if (circle.authorOf(session) case final author?)
                    FeedSessionCard(
                      key: ValueKey(session.id),
                      entry: feedEntry(
                        session,
                        sessions,
                        firstDayOfWeek: firstDay,
                      ),
                      author: author,
                      viewer: viewer,
                    ),
            ],
          ),
        ),
        if (!circle.isFeedLoading && feed.isEmpty && suggestions.isNotEmpty)
          Padding(
            padding: gutter,
            child: AppSection(
              children: [
                for (final user in suggestions)
                  UserRow(
                    user: user,
                    onPressed: () =>
                        SocialNavigation.openProfile(context, user),
                    trailing: FollowButton(
                      state: circle.followState(user.userId),
                      onPressed: () {
                        cubit.pressed('SuggestedFollow_Press');
                        context.read<CircleBloc>().add(
                          CircleFollowPressed(user),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A one-line card with a close button: the username prompt and the
/// Monday recap.
class _Banner extends StatelessWidget {
  const new({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.dismissLabel,
    required this.onDismissed,
    this.onPressed,
    this.detail,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final String dismissLabel;
  final VoidCallback onDismissed;
  final VoidCallback? onPressed;

  /// A second line, under [text].
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.s,
        0,
        AppSpacing.s,
      ),
      child: Row(
        spacing: AppSpacing.m,
        children: [
          ExcludeSemantics(
            child: Icon(
              icon,
              color: iconColor,
              size: AppIconSize.medium.of(context),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: [
                Text(text, style: AppTextStyles.rowTitle),
                if (detail != null)
                  Text(
                    detail,
                    style: AppTextStyles.label.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    final onPressed = this.onPressed;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: onPressed == null
                ? content
                : InkWell(onTap: onPressed, child: content),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s),
            child: AppIconButton(
              icon: AppSymbols.close,
              semanticLabel: dismissLabel,
              onPressed: onDismissed,
            ),
          ),
        ],
      ),
    );
  }
}

/// "This Week": everyone in the circle ranked by sessions, collapsed by
/// default (`CircleLeaderboardView`).
class _Leaderboard extends StatelessWidget {
  const new({
    required this.standings,
    required this.viewerId,
    required this.onPressed,
  });

  final List<CircleStanding> standings;
  final String viewerId;
  final ValueChanged<UserModel> onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return AppCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(l10n.socialThisWeek, style: AppTextStyles.rowTitle),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.s,
            0,
            AppSpacing.s,
            AppSpacing.s,
          ),
          children: [
            for (final (index, standing) in standings.indexed)
              () {
                final rank = index + 1;
                final isOwn = standing.user.userId == viewerId;
                final name = isOwn
                    ? l10n.socialYou
                    : commonNameOf(standing.user) ?? l10n.socialUnknown;
                final met = standing.sessions >= standing.goal;
                return Semantics(
                  button: true,
                  hint: l10n.socialOpensProfile,
                  label: l10n.socialStandingLabel(
                    rank,
                    name,
                    standing.sessions,
                    standing.goal,
                  ),
                  excludeSemantics: true,
                  child: Material(
                    color: isOwn
                        ? AppColors.tintedSurface(scheme.primary)
                        : Colors.transparent,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onPressed(standing.user),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.s),
                        child: Row(
                          spacing: AppSpacing.m,
                          children: [
                            SizedBox(
                              width: MediaQuery.textScalerOf(context).scale(20),
                              child: Text(
                                AppFormat.number(rank, locale: locale),
                                style: AppTextStyles.rowDetail.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            UserAvatar(
                              imageUrl: profileImageOf(standing.user),
                              size: AppControlSize.compact,
                            ),
                            Flexible(
                              child: Text(
                                name,
                                style: isOwn
                                    ? AppTextStyles.rowDetail.semibold
                                    : AppTextStyles.rowDetail,
                              ),
                            ),
                            if (rank == 1 && standing.sessions > 0)
                              Icon(
                                AppSymbols.leader,
                                color: colors.personalRecord,
                                size: AppIconSize.small.of(context),
                              ),
                            const Spacer(),
                            Text(
                              '${standing.sessions}/${standing.goal}',
                              style: AppTextStyles.metricSmall.copyWith(
                                color: met
                                    ? colors.accentInk
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }(),
          ],
        ),
      ),
    );
  }
}

/// The bell: unread rows plus follow requests waiting on an answer
/// (`SocialPresenter.bellBadgeCount`); zero hides the badge.
class _NotificationsButton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final count = context.select<InboxBloc, int>(
      (bloc) => bloc.state.bellBadgeCount,
    );
    return AppToolbarButton(
      icon: AppSymbols.notifications,
      semanticLabel: context.l10n.socialNotificationsButton,
      badgeCount: count,
      onPressed: () => context.pushNamed(NotificationsPage.name),
    );
  }
}
