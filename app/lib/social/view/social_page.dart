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
import 'package:compound_charts/compound_charts.dart';
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
        maxWidth: AppContentWidth.dashboard,
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

/// The tab as a dashboard: the week's standings as the hero, the circle's
/// faces, the prompts, the challenges, then the feed. Wide, the summaries
/// sit in a column beside the feed.
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
    void openStanding(UserModel user) {
      cubit.pressed('LeaderboardRow_Press');
      SocialNavigation.openProfile(context, user);
    }

    final summaries = <Widget>[
      // The hero: where the reader stands in the circle this week.
      if (members.isNotEmpty)
        CircleWeekHero(
          standings: CircleWeek.standings(
            users: [for (final member in members) member.user],
            sessions: sessions,
            now: now,
            firstDayOfWeek: firstDay,
          ),
          viewerId: viewer.userId,
          onPressed: openStanding,
        ),
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
        _Banner(
          icon: AppSymbols.username,
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
      // Last week's recap: the circle's total, the reader's own count.
      if (summary != null)
        AppSummaryCard(
          title: l10n.socialLastWeek,
          icon: AppSymbols.streak,
          tint: context.appColors.workouts,
          value: AppFormat.number(summary.circleSessions),
          unit: l10n.socialCircleSessionsUnit(summary.circleSessions),
          footer: l10n.socialLastWeekYou(summary.ownSessions, summary.ownGoal),
          trailing: AppChip(
            label: l10n.todayStarterHide,
            onPressed: () => context.read<CircleBloc>().add(
              CircleWeeklySummaryDismissed(summary.weekStart),
            ),
          ),
        ),
      if (circle.showsInviteCard)
        _Banner(
          icon: AppSymbols.invite,
          text: l10n.inviteCardTitle,
          detail: l10n.inviteCardMessage,
          dismissLabel: l10n.socialDismiss,
          onPressed: () {
            context.read<CircleBloc>().add(const CircleInviteCardDismissed());
            unawaited(
              context.read<InviteCubit>().shareRequested(
                viewer.userId,
                pressedEvent: 'SocialView_InviteCard_Press',
              ),
            );
          },
          onDismissed: () {
            cubit.pressed('InviteCard_Dismiss');
            context.read<CircleBloc>().add(const CircleInviteCardDismissed());
          },
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
    ];
    final workouts = AppSection(
      header: l10n.socialWorkoutFeed,
      trailing: feed.isEmpty
          ? null
          : AppChip(label: l10n.socialFindPeople, onPressed: onFindPeople),
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
                entry: feedEntry(session, sessions, firstDayOfWeek: firstDay),
                author: author,
                viewer: viewer,
              ),
      ],
    );
    final feedSections = [
      workouts,
      if (!circle.isFeedLoading && feed.isEmpty && suggestions.isNotEmpty)
        AppSection(
          children: [
            for (final user in suggestions)
              UserRow(
                user: user,
                onPressed: () => SocialNavigation.openProfile(context, user),
                trailing: FollowButton(
                  state: circle.followState(user.userId),
                  onPressed: () {
                    cubit.pressed('SuggestedFollow_Press');
                    context.read<CircleBloc>().add(CircleFollowPressed(user));
                  },
                ),
              ),
          ],
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // The strip of faces scrolls to the screen's edges; everything
        // else keeps the margins.
        Widget column(List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.xl,
          children: [
            for (final child in children)
              if (child is CircleStrip)
                child
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                  child: child,
                ),
          ],
        );
        const padding = EdgeInsets.only(
          top: AppSpacing.s,
          bottom: AppSpacing.xl,
        );
        if (constraints.maxWidth < AppContentWidth.twoColumns) {
          return ListView(
            padding: padding,
            children: [
              column([...summaries, ...feedSections]),
            ],
          );
        }
        return SingleChildScrollView(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: column(summaries)),
              Expanded(child: column(feedSections)),
            ],
          ),
        );
      },
    );
  }
}

/// A prompt with a close button: the username prompt and the invite.
class _Banner extends StatelessWidget {
  const new({
    required this.icon,
    required this.text,
    required this.dismissLabel,
    required this.onDismissed,
    required this.onPressed,
    this.detail,
  });

  final IconData icon;
  final String text;
  final String dismissLabel;
  final VoidCallback onDismissed;
  final VoidCallback onPressed;

  /// A second line, under [text].
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: AppPressable(
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.m,
                  0,
                  AppSpacing.m,
                ),
                child: Row(
                  spacing: AppSpacing.m,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        icon,
                        color: context.appColors.accentInk,
                        size: AppIconSize.medium.of(context),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: AppSpacing.xxs,
                        children: [
                          Text(text, style: AppTextStyles.rowTitle.semibold),
                          if (detail != null)
                            Text(
                              detail,
                              style: AppTextStyles.label.secondary(context),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

/// Social's hero: the reader's place in the circle this week, in the
/// largest number on the screen, beside a ring filling in the accent
/// toward their weekly goal; the top of the standings under it, the reader
/// always among them; and the whole table from See All
/// (`CircleLeaderboardView`). Before the reader's first session of the
/// week there is no place to show: the hero is their own count instead.
class CircleWeekHero extends StatelessWidget {
  const new({
    required this.standings,
    required this.viewerId,
    required this.onPressed,
    super.key,
  });

  /// Most sessions first.
  final List<CircleStanding> standings;

  /// The reader.
  final String viewerId;

  /// Opens a member's profile.
  final ValueChanged<UserModel> onPressed;

  /// How many rows the card holds (design-language.md: no more than
  /// three).
  static const shown = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final index = standings.indexWhere((s) => s.user.userId == viewerId);
    if (index < 0) return const SizedBox.shrink();
    final own = standings[index];
    final met = own.sessions >= own.goal;
    final rows = [
      for (final (position, standing) in standings.indexed)
        // The top three, or the top two and the reader below them.
        if (index < shown
            ? position < shown
            : position < shown - 1 || position == index)
          _StandingRow(
            place: CircleWeek.place(standings, standing),
            standing: standing,
            isOwn: position == index,
            onPressed: () => onPressed(standing.user),
          ),
    ];
    final place = CircleWeek.place(standings, own);
    final goal =
        '${AppFormat.number(own.sessions)}/${AppFormat.number(own.goal)}';
    return AppSummaryCard(
      title: l10n.socialThisWeek,
      icon: AppSymbols.leader,
      tint: colors.workouts,
      size: AppSummaryCardSize.hero,
      // A place is earned: until the reader trains this week, the hero is
      // their own count, and the footer says what puts them on the board.
      value: place == null ? goal : l10n.socialRankValue(place),
      unit: place == null
          ? l10n.socialSessionsThisWeekUnit(own.goal)
          : l10n.socialRankUnit(standings.length),
      delta: met
          ? AppChip(
              label: l10n.streakGoalMet,
              icon: AppSymbols.success,
              selected: true,
            )
          : null,
      // The ring is the reader's own week toward their goal: the accent
      // as ink. It keeps its size at large text, as Today's does.
      chart: MediaQuery.withNoTextScaling(
        child: ProgressArc(
          value: CircleWeek.progress(own.sessions, own.goal),
          color: colors.accentInk,
          diameter: 2 * AppControlSize.cta,
          strokeWidth: AppChartMark.arcWidthHero,
        ),
      ),
      chartBeside: true,
      footer: place != null
          ? l10n.streakThisWeek(own.sessions, own.goal)
          : standings.every((s) => s.sessions == 0)
          ? l10n.socialNoOneTrained
          : l10n.socialTrainToRank,
      trailing: standings.length > shown
          ? AppChip(
              label: l10n.socialSeeAll,
              onPressed: () => unawaited(_showAll(context)),
            )
          : null,
      rows: rows,
    );
  }

  Future<void> _showAll(BuildContext context) => showAppSheet<void>(
    context: context,
    builder: (sheet) => ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        AppSection(
          header: sheet.l10n.socialThisWeek,
          children: [
            for (final standing in standings)
              _StandingRow(
                place: CircleWeek.place(standings, standing),
                standing: standing,
                isOwn: standing.user.userId == viewerId,
                onPressed: () {
                  Navigator.of(sheet).pop();
                  onPressed(standing.user);
                },
              ),
          ],
        ),
      ],
    ),
  );
}

/// One row of the week's standings: place and name (the name alone
/// before a first session), face, and sessions out of the goal. Opens the
/// profile.
class _StandingRow extends StatelessWidget {
  const new({
    required this.place,
    required this.standing,
    required this.isOwn,
    required this.onPressed,
  });

  final int? place;
  final CircleStanding standing;
  final bool isOwn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = isOwn
        ? l10n.socialYou
        : commonNameOf(standing.user) ?? l10n.socialUnknown;
    return AppListRowButton(
      title: switch (place) {
        final place? => l10n.socialStandingTitle(place, name),
        null => name,
      },
      thumbnail: UserAvatar(
        imageUrl: profileImageOf(standing.user),
        size: AppControlSize.thumbnail,
      ),
      accessory: AppListRowValue(
        '${AppFormat.number(standing.sessions)}/'
        '${AppFormat.number(standing.goal)}',
      ),
      onPressed: onPressed,
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
