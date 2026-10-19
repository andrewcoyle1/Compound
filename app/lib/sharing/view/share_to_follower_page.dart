import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/sharing/cubit/share_to_follower_cubit.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/view/people_widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_repository/social_repository.dart';

/// Opens Share with Friends for [payload] over the current screen, as
/// Swift's sheet (`showShareToFollowerView`). Nothing happens while no one
/// is signed in.
Future<void> showShareToFollower(BuildContext context, SharePayload payload) {
  final circle = context.read<CircleBloc>().state;
  final viewer = circle.viewer;
  if (viewer == null) return Future.value();
  return showAppSheet<void>(
    context: context,
    size: AppSheetSize.full,
    builder: (_) => BlocProvider(
      create: (context) => ShareToFollowerCubit(
        social: context.read<SocialRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        connectivity: context.read(),
        viewer: viewer,
        payload: payload,
        following: circle.followingUsers,
      )..appeared(),
      child: ShareToFollowerView(
        name: switch (payload) {
          TemplateSharePayload(:final template) => template.name,
          MesocycleSharePayload(:final mesocycle) => mesocycle.name,
        },
      ),
    ),
  );
}

/// The mutuals to send a template or mesocycle to (`ShareToFollowerView`).
class ShareToFollowerView extends StatefulWidget {
  const new({required this.name, super.key});

  /// What is shared, for the title.
  final String name;

  @override
  State<ShareToFollowerView> createState() => _ShareToFollowerViewState();
}

class _ShareToFollowerViewState extends State<ShareToFollowerView> {
  late final ShareToFollowerCubit _cubit;

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

  void _onStatus(BuildContext context, ShareToFollowerState state) {
    if (state.status == ShareSendStatus.sent) {
      unawaited(AppHaptics.success());
      Navigator.of(context).pop();
    } else if (state.status == ShareSendStatus.failed) {
      final l10n = context.l10n;
      unawaited(AppHaptics.error());
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.shareToFollowerFailed}. ${l10n.socialTryAgain}',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ShareToFollowerCubit>().state;
    return BlocListener<ShareToFollowerCubit, ShareToFollowerState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.failureId != current.failureId,
      listener: _onStatus,
      child: AppScaffold(
        appBar: AppBar(
          leading: AppToolbarButton.close(semanticLabel: l10n.socialClose),
          title: Text(l10n.shareToFollowerTitle(widget.name)),
          actions: [
            AppToolbarButton.confirm(
              semanticLabel: l10n.shareToFollowerSend,
              isSaving: state.status == ShareSendStatus.sending,
              onPressed: state.canSend ? _cubit.sendPressed : null,
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              if (state.recipients.isEmpty)
                AppEmptyState(
                  icon: AppSymbols.friends,
                  title: l10n.shareToFollowerNoOneTitle,
                  description: l10n.shareToFollowerNoOneMessage,
                )
              else
                AppSection(
                  footer: l10n.createChallengeMembersFooter,
                  children: [
                    for (final user in state.recipients)
                      SelectablePersonRow(
                        user: user,
                        selected: state.selectedIds.contains(user.userId),
                        onPressed: () => _cubit.recipientPressed(user.userId),
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
