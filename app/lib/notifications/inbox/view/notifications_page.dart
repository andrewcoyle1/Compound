import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/challenges/challenges.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/notifications/inbox/inbox_bloc.dart';
import 'package:compound/notifications/inbox/notification_grouping.dart';
import 'package:compound/notifications/inbox/view/notification_titles.dart';
import 'package:compound/settings/general/view/notification_settings_page.dart';
import 'package:compound/sharing/view/shared_item_page.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/logic/people.dart';
import 'package:compound/social/social_routes.dart';
import 'package:compound/social/view/people_widgets.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The notifications inbox (Swift `NotificationsView`): follow requests to
/// answer, then the activity, grouped, newest first. Opening it marks
/// everything read. Reads the app-wide [InboxBloc].
class NotificationsPage extends StatefulWidget {
  const new({super.key});

  /// Under the Social tab: `/social/notifications`.
  static const path = 'notifications';

  /// The route name.
  static const name = 'notifications';

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final InboxBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<InboxBloc>()..add(const InboxAppeared());
  }

  @override
  void dispose() {
    _bloc.add(const InboxDisappeared());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MultiBlocListener(
      listeners: [
        BlocListener<InboxBloc, InboxState>(
          listenWhen: (previous, current) =>
              current.destinationId != previous.destinationId,
          listener: (context, state) => _open(context, state.destination!),
        ),
        BlocListener<InboxBloc, InboxState>(
          listenWhen: (previous, current) =>
              current.followBackId != previous.followBackId,
          listener: (context, state) => context.read<CircleBloc>().add(
            CircleFollowPressed(state.followBack!),
          ),
        ),
        BlocListener<InboxBloc, InboxState>(
          listenWhen: (previous, current) =>
              current.noticeId != previous.noticeId,
          listener: (context, state) => _showNotice(context, state.notice!),
        ),
      ],
      child: AppScaffold(
        appBar: AppBar(
          title: Text(l10n.inboxTitle),
          actions: [
            AppToolbarButton(
              icon: AppSymbols.settings,
              semanticLabel: l10n.settingsNotificationSettings,
              onPressed: () => context.pushNamed(NotificationSettingsPage.name),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: BlocBuilder<InboxBloc, InboxState>(
            builder: (context, state) {
              if (state.isLoading) {
                return AppLoadingView(label: l10n.launchLoading);
              }
              return RefreshIndicator(
                onRefresh: () async {
                  final bloc = context.read<InboxBloc>()
                    ..add(const InboxLoadRequested());
                  await bloc.stream.firstWhere((state) => !state.isLoading);
                },
                child: _InboxList(state: state),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Browsing pushes: a comment or mention opens the workout with its
  /// thread pushed on top.
  static void _open(BuildContext context, InboxDestination destination) {
    switch (destination) {
      case InboxProfileDestination(:final user):
        SocialNavigation.openProfile(context, user);
      case InboxShareDestination(:final share, :final senderName):
        unawaited(
          SharedItemPage.open(
            context,
            SharedItemRequest(share: share, senderName: senderName),
          ),
        );
      case InboxChallengeDestination(:final challenge):
        ChallengeNavigation.open(context, challenge);
      case InboxSessionDestination(:final session, :final openComments):
        SocialNavigation.openSession(context, session);
        if (openComments) SocialNavigation.openComments(context, session);
    }
  }

  static void _showNotice(BuildContext context, InboxNotice notice) {
    final l10n = context.l10n;
    if (notice == InboxNotice.answerFailed) {
      unawaited(AppHaptics.heavy());
    }
    final (title, message) = switch (notice) {
      InboxNotice.deleteFailed => (l10n.inboxDeleteFailed, l10n.socialTryAgain),
      InboxNotice.followBackFailed => (
        l10n.inboxFollowBackFailed,
        l10n.socialTryAgain,
      ),
      InboxNotice.answerFailed => (l10n.inboxAnswerFailed, l10n.socialTryAgain),
      InboxNotice.openFailed => (
        l10n.inboxOpenFailed,
        l10n.inboxOpenFailedMessage,
      ),
      InboxNotice.loadMoreFailed => (
        l10n.inboxLoadMoreFailed,
        l10n.socialTryAgain,
      ),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$title. $message')));
  }
}

class const _InboxList({required final InboxState state})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = state.groups;
    return ListView(
      // Pull to refresh needs a list that scrolls even when short.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        if (state.requests.isNotEmpty) ...[
          AppSection(
            header: l10n.inboxFollowRequests,
            children: [
              for (final request in state.requests)
                _RequestRow(request: request),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (state.loadFailed)
          AppErrorState(
            title: l10n.inboxLoadFailedTitle,
            description: l10n.inboxLoadFailedMessage,
            actionLabel: l10n.tryAgainButton,
            onAction: () =>
                context.read<InboxBloc>().add(const InboxLoadRequested()),
          )
        else if (groups.isEmpty)
          AppEmptyState(
            icon: AppSymbols.notifications,
            title: l10n.inboxEmptyTitle,
            description: l10n.inboxEmptyMessage,
          )
        else ...[
          AppSection(
            children: [
              for (final group in groups)
                _GroupRow(
                  key: ValueKey(group.id),
                  group: group,
                  opening: state.openingId,
                  showsFollowBack: state.showsFollowBack(group.newest),
                ),
            ],
          ),
          if (state.hasMore)
            Center(
              child: AppTextButton(
                label: l10n.inboxLoadMore,
                onPressed: () =>
                    context.read<InboxBloc>().add(const InboxLoadMorePressed()),
              ),
            ),
        ],
      ],
    );
  }
}

/// A request to follow the reader's private profile, with Accept and
/// Decline.
class const _RequestRow({required final FollowRequestModel request})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<InboxBloc>();
    // At accessibility sizes the row moves the buttons under the name.
    return AppListRow(
      title: request.requesterName,
      subtitle: l10n.inboxWantsToFollow,
      thumbnail: UserAvatar(
        imageUrl: request.requesterImageUrl,
        size: AppControlSize.thumbnail,
      ),
      accessory: AppListRowCustom(
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            AppCtaButton(
              label: l10n.inboxAccept,
              size: AppCtaSize.compact,
              onPressed: () {
                unawaited(AppHaptics.medium());
                bloc.add(InboxRequestAnswered(request, accept: true));
              },
            ),
            AppCtaButton(
              label: l10n.inboxDecline,
              size: AppCtaSize.compact,
              variant: AppCtaVariant.secondary,
              onPressed: () =>
                  bloc.add(InboxRequestAnswered(request, accept: false)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of the activity: stacked avatars (or a spinner while it opens),
/// the title, bold while unread, and the time. The text is one button, so
/// one screen-reader stop; Follow back sits beside it as its own.
class const _GroupRow({
  required final NotificationGroup group,
  required final String? opening,
  required final bool showsFollowBack,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<InboxBloc>();
    final scheme = Theme.of(context).colorScheme;
    final date = AppFormat.dateTime(
      group.newest.dateCreated.toLocal(),
      use24HourFormat: context.use24HourFormat,
      locale: context.dateLocale,
    );
    final followBack = showsFollowBack
        ? BlocSelector<CircleBloc, CircleState, FollowState>(
            selector: (circle) => circle.followState(group.newest.actorId),
            builder: (context, followState) => FollowButton(
              state: followState,
              onPressed: () => bloc.add(InboxFollowBackPressed(group.newest)),
            ),
          )
        : null;
    return AppSwipeActions(
      trailing: [
        AppSwipeAction(
          label: l10n.inboxDelete,
          icon: AppSymbols.delete,
          isDestructive: true,
          onPressed: () => bloc.add(InboxGroupDeleted(group)),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.l),
        child: Row(
          spacing: AppSpacing.m,
          children: [
            Expanded(
              child: Semantics(
                value: group.isRead ? null : l10n.inboxUnread,
                button: true,
                child: InkWell(
                  onTap: opening == null
                      ? () => bloc.add(InboxGroupPressed(group))
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.l,
                      AppSpacing.s,
                      0,
                      AppSpacing.s,
                    ),
                    child: Row(
                      spacing: AppSpacing.m,
                      children: [
                        if (opening == group.newest.id)
                          const SizedBox.square(
                            dimension: AppSpacing.xxl,
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.s),
                              child: CircularProgressIndicator.adaptive(),
                            ),
                          )
                        else
                          _StackedAvatars(urls: group.avatarUrls),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: AppSpacing.xs,
                            children: [
                              Text(
                                notificationGroupTitle(l10n, group),
                                style: group.isRead
                                    ? AppTextStyles.rowTitle.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      )
                                    : AppTextStyles.sectionTitle,
                              ),
                              Text(
                                date,
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
              ),
            ),
            ?followBack,
          ],
        ),
      ),
    );
  }
}

/// Up to three overlapping avatars, the most recent actor on top.
/// Decorative: the title names them.
class const _StackedAvatars({required final List<String?> urls})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const size = AppSpacing.xxl;
    const step = size - AppSpacing.m;
    final surface = Theme.of(context).colorScheme.surface;
    return SizedBox(
      width: size + step * (urls.length - 1),
      height: size,
      child: Stack(
        children: [
          // Drawn oldest first, so the newest lands on top.
          for (var index = urls.length - 1; index >= 0; index--)
            Positioned(
              left: step * index,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: surface, width: 2),
                ),
                child: UserAvatar(imageUrl: urls[index], size: size),
              ),
            ),
        ],
      ),
    );
  }
}
