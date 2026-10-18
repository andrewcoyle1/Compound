import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/followers/people_list_cubit.dart';
import 'package:compound/social/social_routes.dart';
import 'package:compound/social/view/people_widgets.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_repository/social_repository.dart';

/// Which list of people, which names the screen.
enum PeopleListKind { followers, following, mutual }

/// The people to list and what can be done to them
/// (`FollowersListDelegate`).
final class const PeopleListRequest({
  required final PeopleListKind kind,
  required final List<UserModel> people,

  /// Set only for the reader's own followers, who can then be removed.
  final bool canRemove = false,
}) extends Equatable {
  @override
  List<Object> get props => [kind, people, canRemove];
}

/// Followers, Following or People You Both Follow (Swift
/// `FollowersListView`).
class PeopleListPage extends StatelessWidget {
  const new({required this.request, super.key});

  /// Under a profile: `/people/:userId/list`.
  static const path = 'list';

  /// The route name.
  static const name = 'peopleList';

  final PeopleListRequest request;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PeopleListCubit(
        social: context.read<SocialRepository>(),
        analytics: context.read<AnalyticsRepository>(),
      )..appeared(),
      child: PeopleListView(request: request),
    );
  }
}

class PeopleListView extends StatefulWidget {
  const new({required this.request, super.key});

  final PeopleListRequest request;

  @override
  State<PeopleListView> createState() => _PeopleListViewState();
}

class _PeopleListViewState extends State<PeopleListView> {
  late final PeopleListCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<PeopleListCubit>();
  }

  @override
  void dispose() {
    _cubit.disappeared();
    super.dispose();
  }

  Future<void> _confirmRemove(UserModel user) async {
    final l10n = context.l10n;
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(l10n.socialRemoveFollowerTitle),
        content: Text(
          l10n.socialRemoveFollowerMessage(
            fullNameOf(user) ?? l10n.socialThisPerson,
          ),
        ),
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
            child: Text(l10n.socialRemove),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await _cubit.removeConfirmed(user.userId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final request = widget.request;
    final state = context.watch<PeopleListCubit>().state;
    final circle = context.watch<CircleBloc>().state;
    final people = [
      for (final user in request.people)
        if (!state.removedIds.contains(user.userId)) user,
    ];
    return BlocListener<PeopleListCubit, PeopleListState>(
      listenWhen: (previous, current) =>
          previous.failureId != current.failureId,
      listener: (context, _) => showAdaptiveDialog<void>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: Text(l10n.socialRemoveFollowerFailed),
          content: Text(l10n.socialTryAgain),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.settingsOk),
            ),
          ],
        ),
      ),
      child: AppScaffold(
        appBar: AppBar(
          title: Text(switch (request.kind) {
            PeopleListKind.followers => l10n.socialFollowers,
            PeopleListKind.following => l10n.socialFollowing,
            PeopleListKind.mutual => l10n.socialPeopleYouBothFollowTitle,
          }),
        ),
        body: SafeArea(
          child: request.people.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: SocialEmptyState(
                      icon: AppSymbols.friends,
                      title: l10n.socialNoFollowersTitle,
                      message: l10n.socialNoFollowersMessage,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                  children: [
                    for (final user in people)
                      UserRow(
                        user: user,
                        onPressed: () =>
                            SocialNavigation.openProfile(context, user),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: AppSpacing.xs,
                          children: [
                            if (user.userId != circle.viewer?.userId)
                              FollowButton(
                                state: circle.followState(user.userId),
                                onPressed: () => context.read<CircleBloc>().add(
                                  CircleFollowPressed(user),
                                ),
                              ),
                            if (request.canRemove)
                              IconButton(
                                tooltip: l10n.socialRemove,
                                color: context.appColors.danger,
                                onPressed: state.removing
                                    ? null
                                    : () => _confirmRemove(user),
                                icon: const Icon(AppSymbols.delete),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
