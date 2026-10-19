import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/l10n/first_weekday.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/cubit/programs_cubit.dart';
import 'package:compound/settings/account/view/edit_profile_page.dart';
import 'package:compound/settings/view/settings_page.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/feed/feed_entry.dart';
import 'package:compound/social/feed/feed_session_card.dart';
import 'package:compound/social/followers/people_list_page.dart';
import 'package:compound/social/invite/invite_cubit.dart';
import 'package:compound/social/logic/people.dart';
import 'package:compound/social/profile/profile_summary.dart';
import 'package:compound/social/profile/social_profile_cubit.dart';
import 'package:compound/social/report/report_cubit.dart';
import 'package:compound/social/report/report_sheet.dart';
import 'package:compound/social/social_routes.dart';
import 'package:compound/social/view/people_widgets.dart';
import 'package:compound/social/weekly_goal/weekly_goal_sheet.dart';
import 'package:compound/workout_history/workout_history.dart';
import 'package:compound_maths/compound_maths.dart' show weeklySessionGoal;
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_repository/social_repository.dart';

/// Someone's profile, or the reader's own (Swift `SocialProfileView`):
/// who they are, follow, their week, consistency and workouts. A private
/// profile the reader does not follow shows only its header.
class SocialProfilePage extends StatelessWidget {
  const new({
    required this.userId,
    this.user,
    this.isPresentedModally = false,
    super.key,
  });

  /// Over the tabs: `/people/:userId`.
  static const path = '/people/:$userIdParameter';

  /// The route name.
  static const name = 'socialProfile';

  /// The path parameter naming the profile.
  static const userIdParameter = 'userId';

  final String userId;

  /// The profile, when the caller has it.
  final UserModel? user;

  /// The profile button's cover, which needs its own close button.
  final bool isPresentedModally;

  @override
  Widget build(BuildContext context) {
    final viewer = context.read<CircleBloc>().state.viewer;
    if (viewer == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) {
        final cubit = SocialProfileCubit(
          social: context.read<SocialRepository>(),
          analytics: context.read<AnalyticsRepository>(),
          userId: userId,
          user: user,
        );
        unawaited(cubit.appeared(viewer));
        return cubit;
      },
      child: SocialProfileView(isPresentedModally: isPresentedModally),
    );
  }
}

class SocialProfileView extends StatefulWidget {
  const new({this.isPresentedModally = false, super.key});

  final bool isPresentedModally;

  @override
  State<SocialProfileView> createState() => _SocialProfileViewState();
}

class _SocialProfileViewState extends State<SocialProfileView> {
  late final SocialProfileCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<SocialProfileCubit>();
  }

  @override
  void dispose() {
    _cubit.disappeared();
    super.dispose();
  }

  void _showNotice(BuildContext context, SocialProfileState state) {
    final l10n = context.l10n;
    unawaited(
      showAppDialog<void>(
        context: context,
        title: switch (state.notice) {
          SocialProfileNotice.blockFailed => l10n.socialBlockFailed,
          SocialProfileNotice.unblockFailed => l10n.socialUnblockFailed,
          _ => l10n.socialFollowingLoadFailed,
        },
        message: l10n.socialTryAgain,
        actions: [AppDialogAction(label: l10n.settingsOk)],
      ),
    );
  }

  Future<void> _confirmBlock(UserModel user, UserModel viewer) async {
    final l10n = context.l10n;
    final name = fullNameOf(user) ?? l10n.socialUser;
    final confirmed = await AppDialog.confirmDestructive(
      context,
      title: l10n.socialBlockTitle(name),
      message: l10n.socialBlockMessage,
      confirmLabel: l10n.socialBlock,
      cancelLabel: l10n.commentsCancel,
    );
    if (confirmed) await _cubit.blockConfirmed(viewer);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<SocialProfileCubit>().state;
    final circle = context.watch<CircleBloc>().state;
    final viewer = circle.viewer;
    final stateUser = state.user;
    // The reader's own profile reads live, so it changes when Edit Profile
    // saves.
    final user = stateUser?.userId == viewer?.userId ? viewer : stateUser;
    if (user == null || viewer == null) {
      return AppScaffold(
        appBar: AppBar(
          leading: widget.isPresentedModally
              ? AppToolbarButton.close(
                  semanticLabel: l10n.socialClose,
                  onPressed: () => context.pop(),
                )
              : null,
          title: Text(l10n.profileTitle),
        ),
        body: state.notFound
            ? AppErrorState(
                icon: AppSymbols.profile,
                title: l10n.socialProfileNotFound,
              )
            : AppLoadingView(label: l10n.launchLoading),
      );
    }
    final summary = ProfileSummary(
      user: user,
      circle: circle,
      fetchedSessions: state.sessions,
      now: DateTime.now(),
      firstDayOfWeek: firstDayOfWeekIndex(context),
    );
    final username = user.username;
    return MultiBlocListener(
      listeners: [
        BlocListener<SocialProfileCubit, SocialProfileState>(
          listenWhen: (previous, current) =>
              previous.noticeId != current.noticeId,
          listener: _showNotice,
        ),
        BlocListener<SocialProfileCubit, SocialProfileState>(
          listenWhen: (previous, current) =>
              previous.followingId != current.followingId,
          listener: (context, state) => SocialNavigation.openPeople(
            context,
            user.userId,
            PeopleListRequest(
              kind: PeopleListKind.following,
              people: state.following ?? const [],
            ),
          ),
        ),
      ],
      child: AppScaffold(
        appBar: AppBar(
          leading: widget.isPresentedModally
              ? AppToolbarButton.close(
                  semanticLabel: l10n.socialClose,
                  onPressed: () => context.pop(),
                )
              : null,
          title: Text(
            username == null || username.isEmpty
                ? l10n.profileTitle
                : l10n.profileUsernameHandle(username),
          ),
          actions: [
            if (summary.isOwn)
              AppToolbarButton(
                icon: AppSymbols.settings,
                semanticLabel: l10n.settingsTitle,
                onPressed: () {
                  _cubit.settingsPressed();
                  unawaited(context.pushNamed(SettingsPage.name));
                },
              )
            else
              MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    leadingIcon: const Icon(AppSymbols.block),
                    onPressed: () => summary.isBlocked
                        ? _cubit.unblockPressed(viewer)
                        : _confirmBlock(user, viewer),
                    child: Text(
                      summary.isBlocked
                          ? l10n.socialUnblock
                          : l10n.socialBlockMenu(
                              fullNameOf(user) ?? l10n.socialUser,
                            ),
                    ),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(AppSymbols.report),
                    onPressed: () => unawaited(
                      showReportSheet(
                        context,
                        ReportedContent(
                          type: ReportContentType.user,
                          id: user.userId,
                          authorId: user.userId,
                        ),
                      ),
                    ),
                    child: Text(l10n.reportMenu),
                  ),
                ],
                builder: (context, controller, _) => AppToolbarButton(
                  icon: AppSymbols.more,
                  semanticLabel: l10n.socialMoreActions,
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              _Header(summary: summary, followers: state.followers),
              if (!summary.isLocked) ...[
                const SizedBox(height: AppSpacing.l),
                AppSegmentedControl<SocialProfileTab>(
                  segments: [
                    AppSegment(
                      value: SocialProfileTab.progress,
                      label: l10n.tabProgress,
                    ),
                    AppSegment(
                      value: SocialProfileTab.activities,
                      label: l10n.socialActivities,
                    ),
                  ],
                  selected: state.tab,
                  onChanged: _cubit.tabChanged,
                ),
                const SizedBox(height: AppSpacing.l),
                if (state.tab == SocialProfileTab.progress)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpacing.xl,
                    children: [
                      _ThisWeek(summary: summary),
                      _Consistency(summary: summary),
                      // Strava's terms keep an athlete's data to the
                      // athlete: the reader's own profile only.
                      if (summary.isOwn)
                        StravaYearSection(
                          distanceUnit:
                              summary.user.submittedDistanceUnitPreference,
                        ),
                    ],
                  )
                else
                  _Activities(summary: summary, state: state),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const new({required this.summary, required this.followers});

  final ProfileSummary summary;
  final List<UserModel> followers;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final cubit = context.read<SocialProfileCubit>();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final user = summary.user;
    final viewer = summary.viewer!;
    final name = fullNameOf(user);
    final secondary = AppTextStyles.label.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final count = summary.workoutCount;
    final streak = summary.latestStreak;
    // Only the reader's own mesocycle is known without reading someone
    // else's (`SocialProfilePresenter.mesocycleName`).
    final mesocycle = context.select<ProgramsCubit, String?>(
      (cubit) => cubit.state.activeMesocycle?.name,
    );
    final isLargeText =
        MediaQuery.textScalerOf(context).scale(1) >=
        AppListRow.accessibilityTextScale;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        if (name != null) Text(name, style: AppTextStyles.sectionTitle),
        if (count != null)
          Text(l10n.socialWorkoutCount(count), style: secondary),
        if (summary.followsYou) Text(l10n.socialFollowsYou, style: secondary),
        if (streak != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xs,
            children: [
              Icon(
                AppSymbols.streak,
                size: AppIconSize.small.of(context),
                color: colors.workouts,
              ),
              Text(
                l10n.highlightStreak(streak),
                style: AppTextStyles.label.copyWith(color: colors.workouts),
              ),
            ],
          ),
        if (summary.isOwn && mesocycle != null)
          Text(l10n.profileFollowingMesocycle(mesocycle), style: secondary),
        if (summary.isOwn)
          Semantics(
            hint: l10n.socialChangeGoalHint,
            child: AppChip(
              icon: AppSymbols.goal,
              label: user.weeklySessionGoal == null
                  ? l10n.socialSetWeeklyGoal
                  : l10n.socialGoalText(
                      weeklySessionGoal(user.weeklySessionGoal),
                    ),
              onPressed: () {
                cubit.weeklyGoalPressed();
                unawaited(showWeeklyGoalSheet(context, viewer));
              },
            ),
          ),
      ],
    );
    final follow = summary.showsFollowButton
        ? FollowButton(
            state: summary.followState,
            onPressed: () {
              cubit.followPressed(
                following: summary.followState == FollowState.following,
                requested: summary.followState == FollowState.requested,
              );
              context.read<CircleBloc>().add(CircleFollowPressed(user));
            },
          )
        : null;
    void openPeople(PeopleListRequest request) =>
        SocialNavigation.openPeople(context, user.userId, request);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.l,
          children: [
            if (isLargeText)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.l,
                children: [
                  UserAvatar(imageUrl: profileImageOf(user), size: 80),
                  details,
                  ?follow,
                ],
              )
            else
              Row(
                spacing: AppSpacing.l,
                children: [
                  UserAvatar(imageUrl: profileImageOf(user), size: 80),
                  Expanded(child: details),
                  ?follow,
                ],
              ),
            const Divider(height: 1),
            if (summary.isBlocked)
              _IconLine(icon: AppSymbols.block, text: l10n.socialBlockedAccount)
            else
              Row(
                spacing: AppSpacing.xxl,
                children: [
                  _CountButton(
                    value: AppFormat.number(followers.length, locale: locale),
                    label: l10n.socialFollowers,
                    onPressed: summary.isLocked
                        ? null
                        : () => openPeople(
                            PeopleListRequest(
                              kind: PeopleListKind.followers,
                              people: followers,
                              canRemove: summary.isOwn,
                            ),
                          ),
                  ),
                  _CountButton(
                    value: AppFormat.number(
                      user.followingIds?.length ?? 0,
                      locale: locale,
                    ),
                    label: l10n.socialFollowing,
                    onPressed: summary.isLocked
                        ? null
                        : () => cubit.followingPressed(viewer),
                  ),
                ],
              ),
            if (summary.isOwn)
              Row(
                spacing: AppSpacing.s,
                children: [
                  Expanded(
                    child: AppCtaButton(
                      label: l10n.profileEditProfile,
                      size: AppCtaSize.compact,
                      variant: AppCtaVariant.secondary,
                      onPressed: () {
                        cubit.editProfilePressed();
                        unawaited(context.pushNamed(EditProfilePage.name));
                      },
                    ),
                  ),
                  // The invite link is the profile's shareable link:
                  // accepting it opens this profile.
                  Expanded(
                    child: AppCtaButton(
                      label: l10n.profileShareProfile,
                      size: AppCtaSize.compact,
                      variant: AppCtaVariant.secondary,
                      onPressed: () => unawaited(
                        context.read<InviteCubit>().shareRequested(
                          user.userId,
                          pressedEvent:
                              'SocialProfileView_ShareProfile_Pressed',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (!summary.isBlocked && summary.isLocked)
              _IconLine(icon: AppSymbols.lock, text: l10n.socialPrivateLocked),
            if (!summary.isBlocked &&
                !summary.isLocked &&
                summary.mutualFollowers.isNotEmpty) ...[
              const Divider(height: 1),
              Row(
                spacing: AppSpacing.s,
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      height: AppControlSize.thumbnail,
                      width:
                          AppControlSize.thumbnail +
                          (summary.mutualFollowers.take(5).length - 1) *
                              (AppControlSize.thumbnail - AppSpacing.m),
                      child: Stack(
                        children: [
                          for (final (index, mutual)
                              in summary.mutualFollowers.take(5).indexed)
                            Positioned(
                              left:
                                  index *
                                  (AppControlSize.thumbnail - AppSpacing.m),
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  shape: CircleBorder(
                                    side: BorderSide(
                                      color: colors.canvas,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: UserAvatar(
                                  imageUrl: profileImageOf(mutual),
                                  size: AppControlSize.thumbnail,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l10n.socialPeopleYouBothFollow,
                      style: secondary,
                    ),
                  ),
                  AppTextButton(
                    label: l10n.socialSeeAll,
                    onPressed: () => openPeople(
                      PeopleListRequest(
                        kind: PeopleListKind.mutual,
                        people: summary.mutualFollowers,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const new({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.s,
      children: [
        Icon(icon, size: AppIconSize.small.of(context), color: secondary),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.rowDetail.copyWith(color: secondary),
          ),
        ),
      ],
    );
  }
}

class _CountButton extends StatelessWidget {
  const new({required this.value, required this.label, this.onPressed});

  final String value;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onPressed != null,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppControlSize.row),
          child: AppStat(value: value, label: label, size: AppStatSize.small),
        ),
      ),
    );
  }
}

class _ThisWeek extends StatelessWidget {
  const new({required this.summary});

  final ProfileSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final unit = WorkoutText.preferredWeightUnit(
      summary.viewer?.submittedWeightUnitPreference,
    );
    return AppSection(
      header: l10n.socialThisWeek,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Wrap(
            spacing: AppSpacing.xxl,
            runSpacing: AppSpacing.s,
            children: [
              AppStat(
                value: AppFormat.number(
                  summary.thisWeek.length,
                  locale: locale,
                ),
                label: l10n.socialWorkouts,
                size: AppStatSize.small,
              ),
              AppStat(
                value: AppFormat.duration(summary.thisWeekDuration),
                label: l10n.socialTime,
                size: AppStatSize.small,
              ),
              AppStat(
                value: AppFormat.weight(
                  summary.thisWeekVolumeKg,
                  unit,
                  locale: locale,
                ),
                label: l10n.statVolume,
                size: AppStatSize.small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Training days over the last twelve weeks, a square per day, a column
/// per week (Swift's `ContributionChart`).
class _Consistency extends StatelessWidget {
  const new({required this.summary});

  final ProfileSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final firstDay = firstDayOfWeekIndex(context);
    final now = DateTime.now();
    final thisWeek = WorkoutSessionHighlights.weekStart(now, firstDay);
    final today = DateTime(now.year, now.month, now.day);
    const weeks = 12;
    return AppSection(
      header: l10n.socialConsistency,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Semantics(
            label: l10n.socialTrainingDays(summary.trainingDays.length),
            excludeSemantics: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = AppSpacing.xs;
                final side = (constraints.maxWidth - gap * (weeks - 1)) / weeks;
                return Row(
                  spacing: gap,
                  children: [
                    for (var week = weeks - 1; week >= 0; week--)
                      Column(
                        spacing: gap,
                        children: [
                          for (var day = 0; day < 7; day++)
                            () {
                              final date = DateTime(
                                thisWeek.year,
                                thisWeek.month,
                                thisWeek.day - week * 7 + day,
                              );
                              final trained = summary.trainingDays.contains(
                                date,
                              );
                              return SizedBox.square(
                                dimension: side,
                                child: date.isAfter(today)
                                    ? null
                                    : DecoratedBox(
                                        decoration: ShapeDecoration(
                                          shape: RoundedSuperellipseBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.s / 2,
                                            ),
                                          ),
                                          color: trained
                                              ? colors.workouts
                                              : scheme.surfaceContainerHighest,
                                        ),
                                      ),
                              );
                            }(),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Activities extends StatelessWidget {
  const new({required this.summary, required this.state});

  final ProfileSummary summary;
  final SocialProfileState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final firstDay = firstDayOfWeekIndex(context);
    final sessions = summary.sessions;
    return AppSection(
      header: l10n.socialRecentWorkouts,
      grouped: false,
      children: [
        if (state.isLoadingSessions && sessions.isEmpty)
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
        else if (state.loadSessionsFailed)
          AppErrorState(
            title: l10n.socialSessionsLoadFailed,
            description: l10n.commentsLoadFailedMessage,
            actionLabel: l10n.tryAgainButton,
            onAction: context.read<SocialProfileCubit>().loadSessions,
          )
        else if (sessions.isEmpty)
          AppEmptyState(
            icon: AppSymbols.workout,
            title: l10n.socialNoWorkoutsTitle,
            description: l10n.socialNoWorkoutsMessage,
          )
        else
          for (final session in sessions)
            FeedSessionCard(
              key: ValueKey(session.id),
              entry: feedEntry(session, sessions, firstDayOfWeek: firstDay),
              author: summary.user,
              viewer: summary.viewer,
            ),
      ],
    );
  }
}
