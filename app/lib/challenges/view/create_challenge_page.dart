import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/challenges/cubit/challenges_cubit.dart';
import 'package:compound/challenges/cubit/create_challenge_cubit.dart';
import 'package:compound/challenges/logic/challenge_standings.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/view/people_widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_repository/social_repository.dart';

/// New Challenge (`CreateChallengeView`): a name, a target and a length,
/// then the mutuals to invite.
class CreateChallengePage extends StatelessWidget {
  const new({super.key});

  /// The route's path, over the tabs.
  static const path = '/challenges/new';

  /// The route's name.
  static const name = 'createChallenge';

  @override
  Widget build(BuildContext context) {
    // Built once the circle knows who is signed in, which a link opened at
    // launch can beat.
    context.select<CircleBloc, bool>((bloc) => bloc.state.viewer != null);
    final circle = context.read<CircleBloc>().state;
    final viewer = circle.viewer;
    if (viewer == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => CreateChallengeCubit(
        social: context.read<SocialRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        viewer: viewer,
        following: circle.followingUsers,
      )..appeared(),
      child: const CreateChallengeView(),
    );
  }
}

class CreateChallengeView extends StatefulWidget {
  const new({super.key});

  @override
  State<CreateChallengeView> createState() => _CreateChallengeViewState();
}

class _CreateChallengeViewState extends State<CreateChallengeView> {
  late final CreateChallengeCubit _cubit;

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

  Future<void> _cancel() async {
    if (!_cubit.state.hasUnsavedChanges) {
      context.pop();
      return;
    }
    final l10n = context.l10n;
    final discard = await AppDialog.confirmDestructive(
      context,
      title: l10n.discardChangesTitle,
      confirmLabel: l10n.discardChangesButton,
      cancelLabel: l10n.keepEditingButton,
    );
    if (discard && mounted) context.pop();
  }

  void _onStatus(BuildContext context, CreateChallengeState state) {
    final l10n = context.l10n;
    switch (state.status) {
      case CreateChallengeStatus.created:
        unawaited(AppHaptics.success());
        context.read<ChallengesCubit>().added(state.created!);
        context.pop();
      case CreateChallengeStatus.failed:
        unawaited(AppHaptics.error());
        showAppSnackBar(
          context,
          '${l10n.createChallengeFailed}. ${l10n.socialTryAgain}',
          style: AppSnackBarStyle.error,
        );
      case CreateChallengeStatus.editing || CreateChallengeStatus.saving:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<CreateChallengeCubit>().state;
    return BlocListener<CreateChallengeCubit, CreateChallengeState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.failureId != current.failureId,
      listener: _onStatus,
      child: PopScope(
        canPop: !state.hasUnsavedChanges,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_cancel());
        },
        child: AppScaffold(
          appBar: AppBar(
            leading: AppToolbarButton.close(
              semanticLabel: l10n.socialClose,
              onPressed: _cancel,
            ),
            title: Text(l10n.createChallengeTitle),
            actions: [
              AppToolbarButton.confirm(
                semanticLabel: l10n.createChallengeCreate,
                isSaving: state.status == CreateChallengeStatus.saving,
                onPressed: state.canCreate ? _cubit.createPressed : null,
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                AppSection(
                  header: l10n.createChallengeSetup,
                  footer: _validationText(l10n, state.validation),
                  children: [
                    AppTextFieldRow(
                      label: l10n.createChallengeName,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      onChanged: _cubit.titleChanged,
                    ),
                    _TargetStepper(target: state.targetSessions),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      child: Semantics(
                        label: l10n.createChallengeDuration,
                        child: AppSegmentedControl<int>(
                          segments: [
                            for (final days in challengeDurations)
                              AppSegment(
                                value: days,
                                label: l10n.createChallengeDays(days),
                              ),
                          ],
                          selected: state.durationDays,
                          onChanged: _cubit.durationChanged,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                if (state.candidates.isEmpty)
                  AppEmptyState(
                    icon: AppSymbols.friends,
                    title: l10n.createChallengeNoOneTitle,
                    description: l10n.createChallengeNoOneMessage,
                  )
                else
                  AppSection(
                    header: l10n.createChallengeMembers,
                    footer: l10n.createChallengeMembersFooter,
                    children: [
                      for (final user in state.candidates)
                        SelectablePersonRow(
                          user: user,
                          selected: state.selectedIds.contains(user.userId),
                          onPressed: () => _cubit.candidatePressed(user.userId),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String? _validationText(
    AppLocalizations l10n,
    ChallengeValidation? validation,
  ) => switch (validation) {
    null => null,
    ChallengeValidation.noName => l10n.createChallengeNoName,
    ChallengeValidation.nameTooLong => l10n.createChallengeNameTooLong(
      challengeTitleMaxLength,
    ),
    ChallengeValidation.targetOutOfRange => l10n.createChallengeTargetRange(
      challengeTargetMin,
      challengeTargetMax,
    ),
    ChallengeValidation.noDuration => l10n.createChallengeNoDuration,
    ChallengeValidation.noMembers => l10n.createChallengeNoMembers,
  };
}

/// "Target: 8 sessions" with − and + (Swift's `Stepper`), 1 to 100.
class _TargetStepper extends StatelessWidget {
  const new({required this.target});

  final int target;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CreateChallengeCubit>();
    return AppListRow(
      title: l10n.createChallengeTarget(target),
      accessory: AppListRowCustom(
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s,
          children: [
            AppIconButton(
              icon: AppSymbols.decrease,
              semanticLabel: l10n.createChallengeTarget(target - 1),
              onPressed: target > challengeTargetMin
                  ? () => cubit.targetChanged(target - 1)
                  : null,
            ),
            AppIconButton(
              icon: AppSymbols.add,
              semanticLabel: l10n.createChallengeTarget(target + 1),
              onPressed: target < challengeTargetMax
                  ? () => cubit.targetChanged(target + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
