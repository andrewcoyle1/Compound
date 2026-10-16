import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/cubit/mesocycle_design_cubit.dart';
import 'package:compound/programs/cubit/programs_cubit.dart';
import 'package:compound/programs/view/mesocycle_settings_page.dart';
import 'package:compound/programs/view/program_widgets.dart';
import 'package:compound/sharing/view/share_to_follower_page.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound/workout_editor/view/define_workout_editor.dart';
import 'package:compound_models/compound_models.dart'
    show MesocycleSharePayload;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:program_repository/program_repository.dart';

/// The days of a mesocycle, new or saved (Swift `MesocycleDesignView`):
/// a tab per day, Add Day, Remove and Rename, the settings, and Activate and
/// Save. Each day's exercises are the workout editor's
/// ([DefineWorkoutEditor]). As the create flow's last step it has a back
/// button; on a saved mesocycle it is the editor, with Close (asking first
/// when something changed) and Delete.
class const MesocycleDesignPage({
  final Mesocycle? draft,
  final String? mesocycleId,
  super.key,
}) extends StatefulWidget {
  /// The path of the create flow's last step, under the name step.
  static const createPath = 'design';

  /// The create step's route name; the new mesocycle is the route's extra.
  static const createName = 'createMesocycleDesign';

  /// The editor's path under the Training tab.
  static const editPath = 'edit-mesocycle/:$idParameter';

  /// The editor's route name.
  static const editName = 'editMesocycle';

  /// The path parameter holding the mesocycle's id.
  static const idParameter = 'mesocycleId';

  /// Opens the editor on the saved mesocycle [id].
  static Future<void> edit(BuildContext context, String id) =>
      context.pushNamed(editName, pathParameters: {idParameter: id});

  @override
  State<MesocycleDesignPage> createState() => _MesocycleDesignPageState();
}

class _MesocycleDesignPageState extends State<MesocycleDesignPage> {
  /// The mesocycle as the editor opened it, kept once found: deleting it
  /// from here must not take the screen out from under the dismissal.
  Mesocycle? _opened;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppBloc>().state;
    final programs = context.watch<ProgramsCubit>().state;
    final mesocycle = _opened ??=
        widget.draft ??
        programs.mesocycles
            .where((m) => m.id == widget.mesocycleId)
            .firstOrNull;
    if (app is! AppAuthenticated || mesocycle == null) {
      return Scaffold(
        appBar: AppBar(),
        body: programs.status == ProgramsStatus.loading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : LibraryEmptyState(
                icon: AppSymbols.mesocycle,
                title: context.l10n.programNoMesocycles,
              ),
      );
    }
    final l10n = context.l10n;
    return BlocProvider(
      create: (context) => MesocycleDesignCubit(
        mesocycle: mesocycle,
        uid: app.user.uid,
        labels: DayNameLabels(
          restDay: l10n.programRestDay,
          workout: l10n.programWorkoutDayName,
        ),
        programs: context.read<ProgramRepository>(),
        service: context.read<ProgramService>(),
        analytics: context.read<AnalyticsRepository>(),
      ),
      // The create flow closes its three screens; the editor, itself.
      child: MesocycleDesignView(isEditing: widget.draft == null),
    );
  }
}

class const MesocycleDesignView({required final bool isEditing, super.key})
    extends StatelessWidget {
  /// Leaves the editor: the create flow's name, icon and design screens,
  /// or the editor alone.
  void _close(BuildContext context) {
    final router = GoRouter.of(context);
    for (var i = 0; i < (isEditing ? 1 : 3); i++) {
      if (router.canPop()) router.pop();
    }
  }

  Future<void> _closePressed(BuildContext context) async {
    final l10n = context.l10n;
    if (!context.read<MesocycleDesignCubit>().state.hasUnsavedChanges) {
      _close(context);
      return;
    }
    final discard = await confirmDestructive(
      context,
      title: l10n.discardChangesTitle,
      confirmLabel: l10n.discardChangesButton,
    );
    if (discard && context.mounted) _close(context);
  }

  Future<void> _deletePressed(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<MesocycleDesignCubit>();
    final confirmed = await confirmDestructive(
      context,
      title: l10n.programDeleteMesocycle,
      message: l10n.programDeleteQuotedMessage(cubit.state.mesocycle.name),
      confirmLabel: l10n.programDeleteMesocycle,
    );
    if (confirmed) await cubit.delete();
  }

  Future<void> _renamePressed(BuildContext context) async {
    final cubit = context.read<MesocycleDesignCubit>();
    final day = cubit.state.selectedDay;
    final name = await showRenameSheet(
      context,
      title: context.l10n.programRenameDayTitle,
      initialName: day.name,
    );
    if (name != null) cubit.renameDay(day.workoutId, name);
  }

  Future<void> _openSettings(BuildContext context) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider.value(
            value: context.read<MesocycleDesignCubit>(),
            child: const MesocycleSettingsPage(),
          ),
        ),
      );

  Future<void> _done(BuildContext context, MesocycleDesignState state) async {
    final l10n = context.l10n;
    // Activating from the settings page is that page's to answer.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (state.status == MesocycleDesignStatus.succeeded) {
      unawaited(HapticFeedback.successNotification());
      if (context.mounted) _close(context);
      return;
    }
    unawaited(HapticFeedback.errorNotification());
    if (!context.mounted) return;
    await showFailureAlert(context, switch (state.lastAction) {
      MesocycleDesignAction.activate => l10n.programActivateFailed,
      MesocycleDesignAction.delete => l10n.programDeleteFailed,
      _ => l10n.programSaveMesocycleFailed,
    }, l10n.programTryAgain);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<MesocycleDesignCubit>().state;
    final cubit = context.read<MesocycleDesignCubit>();
    final isActive =
        context.select<ProgramsCubit, String?>(
          (cubit) => cubit.state.activeMesocycleId,
        ) ==
        state.mesocycle.id;
    final saving = state.status == MesocycleDesignStatus.saving;
    return BlocListener<MesocycleDesignCubit, MesocycleDesignState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          (current.status == MesocycleDesignStatus.succeeded ||
              current.status == MesocycleDesignStatus.failed),
      listener: (context, state) => unawaited(_done(context, state)),
      child: PopScope(
        // The create flow keeps the back button and its swipe, to step back
        // to the icon; the editor asks before losing changes.
        canPop: !isEditing || !state.hasUnsavedChanges,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_closePressed(context));
        },
        child: Scaffold(
          appBar: AppBar(
            leading: isEditing
                ? IconButton(
                    key: const Key('ProgramDesign.close'),
                    icon: const Icon(AppSymbols.close),
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    onPressed: () => unawaited(_closePressed(context)),
                  )
                : null,
            title: Text(
              isEditing
                  ? l10n.programEditMesocycle
                  : l10n.programCreateMesocycle,
            ),
            actions: [
              IconButton(
                icon: const Icon(AppSymbols.settings),
                tooltip: l10n.programMesocycleSettingsLabel,
                onPressed: () => unawaited(_openSettings(context)),
              ),
              if (isEditing)
                PopupMenuButton<void>(
                  icon: Icon(AppSymbols.more),
                  tooltip: l10n.programMore,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      onTap: () => unawaited(
                        showShareToFollower(
                          context,
                          MesocycleSharePayload(state.mesocycle),
                        ),
                      ),
                      child: Text(l10n.shareWithFriends),
                    ),
                    PopupMenuItem(
                      onTap: () => unawaited(_deletePressed(context)),
                      child: Text(
                        l10n.programDeleteMesocycle,
                        style: TextStyle(color: context.appColors.danger),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DayBar(state: state, onAdd: cubit.addDay),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.l,
                    vertical: AppSpacing.xs,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.s,
                    children: [
                      OutlinedButton.icon(
                        onPressed: state.canRemoveDay
                            ? cubit.removeSelectedDay
                            : null,
                        icon: const Icon(AppSymbols.delete),
                        label: Text(l10n.programRemoveDay),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.appColors.danger,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => unawaited(_renamePressed(context)),
                        icon: const Icon(AppSymbols.edit),
                        label: Text(l10n.programRenameDay),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  // A day of its own each, as Swift's `.id(dayPlan.id)`.
                  child: DefineWorkoutEditor(
                    key: ValueKey(state.selectedDay.workoutId),
                    exercises: state.selectedDay.exercises,
                    read: () => cubit.state.selectedDay.exercises,
                    write: cubit.setSelectedDayExercises,
                    isMesocycleDay: true,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: AppBottomCta(
            children: [
              if (!isActive)
                AppCtaButton(
                  key: const Key('ProgramDesign.activate'),
                  label: l10n.programActivateMesocycle,
                  isLoading:
                      saving &&
                      state.lastAction != MesocycleDesignAction.delete,
                  onPressed: state.canSave
                      ? () => unawaited(cubit.activate())
                      : null,
                ),
              AppCtaButton(
                key: const Key('ProgramDesign.save'),
                label: l10n.programSaveMesocycle,
                variant: AppCtaVariant.secondary,
                onPressed: state.canSave ? () => unawaited(cubit.save()) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A button per day, the selected one filled, then Add Day.
class const _DayBar({
  required final MesocycleDesignState state,
  required final VoidCallback onAdd,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MesocycleDesignCubit>();
    final selected = state.selectedDay.workoutId;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.s,
      ),
      child: Row(
        spacing: AppSpacing.s,
        children: [
          for (final day in state.days)
            Semantics(
              selected: day.workoutId == selected,
              child: day.workoutId == selected
                  ? FilledButton(
                      onPressed: () => cubit.selectDay(day.workoutId),
                      child: Text(day.name),
                    )
                  : OutlinedButton(
                      onPressed: () {
                        unawaited(HapticFeedback.selectionClick());
                        cubit.selectDay(day.workoutId);
                      },
                      child: Text(day.name),
                    ),
            ),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(AppSymbols.add),
            label: Text(context.l10n.programAddDay),
          ),
        ],
      ),
    );
  }
}
