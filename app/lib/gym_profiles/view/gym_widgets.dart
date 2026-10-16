import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/gym_profiles/cubit/gym_profile_editor_cubit.dart';
import 'package:compound/gym_profiles/view/gym_text.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// Pushes [page] over the gym editor, sharing its cubit.
Future<T?> pushGymPage<T>(BuildContext context, Widget page) {
  final cubit = context.read<GymProfileEditorCubit>();
  return Navigator.of(context).push(
    MaterialPageRoute<T>(
      builder: (_) => BlocProvider.value(value: cubit, child: page),
    ),
  );
}

/// Shows [sheet] over the gym editor, sharing its cubit.
Future<T?> showGymSheet<T>(BuildContext context, Widget sheet) {
  final cubit = context.read<GymProfileEditorCubit>();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(value: cubit, child: sheet),
  );
}

/// Logs `<screen>_Appear` and `<screen>_Disappear` for a screen without a
/// cubit of its own, as each Swift equipment presenter does.
mixin ScreenAnalytics<T extends StatefulWidget> on State<T> {
  /// The Swift view's name, such as `EditFreeWeightView`.
  String get screen;

  late final AnalyticsRepository _analytics;

  @override
  void initState() {
    super.initState();
    _analytics = context.read<AnalyticsRepository>()..appear(screen);
  }

  @override
  void dispose() {
    _analytics.disappear(screen);
    super.dispose();
  }
}

/// The gym being edited, from the editor's cubit.
GymProfileModel watchGym(BuildContext context) => context
    .select<GymProfileEditorCubit, GymProfileModel>((cubit) => cubit.state.gym);

/// The kilogram and pound switch the weight editors head their lists with.
class WeightUnitSwitch extends StatelessWidget {
  const new({required this.unit, required this.onChanged, super.key});

  final ExerciseWeightUnit unit;
  final ValueChanged<ExerciseWeightUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ExerciseWeightUnit>(
      showSelectedIcon: false,
      segments: [
        for (final unit in ExerciseWeightUnit.values)
          ButtonSegment(
            value: unit,
            label: Text(WorkoutText.weightUnit(unit).symbol),
          ),
      ],
      selected: {unit},
      onSelectionChanged: (selection) => onChanged(selection.single),
    );
  }
}

/// A list header with a trailing control, such as the unit switch.
class GymListHeader extends StatelessWidget {
  const new({required this.title, required this.trailing, super.key});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.m,
        runSpacing: AppSpacing.s,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: AppTextStyles.sectionTitle),
          ),
          trailing,
        ],
      ),
    );
  }
}

/// A row that swipes away to delete, with the same delete as a screen
/// reader action.
class DeletableRow extends StatelessWidget {
  const new({
    required this.id,
    required this.onDelete,
    required this.child,
    super.key,
  });

  final String id;
  final VoidCallback onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: scheme.error,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: Icon(AppSymbols.delete, color: scheme.onError),
          ),
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: context.l10n.gymDelete): onDelete,
        },
        child: child,
      ),
    );
  }
}

/// An empty weight list: "No Pounds weights".
class NoWeights extends StatelessWidget {
  const new({required this.unit, super.key});

  final ExerciseWeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        spacing: AppSpacing.s,
        children: [
          Icon(
            AppSymbols.equipment,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          Text(
            l10n.gymNoUnitWeights(GymText.unitName(l10n, unit)),
            style: AppTextStyles.rowTitle,
            textAlign: TextAlign.center,
          ),
          Text(l10n.gymNoUnitWeightsMessage, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// A sheet's frame: close, the title (and what it is for), and an
/// optional confirm, over [children] (Swift's `.close` and `.confirm`
/// toolbar buttons).
class GymSheet extends StatelessWidget {
  const new({
    required this.title,
    required this.children,
    this.subtitle,
    this.onConfirm,
    this.confirms = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Whether the sheet has a confirm button; [onConfirm] null disables it.
  final bool confirms;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = this.subtitle;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.m,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(AppSymbols.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Column(
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.rowTitle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.rowDetail,
                          ),
                      ],
                    ),
                  ),
                ),
                if (confirms)
                  IconButton(
                    icon: const Icon(AppSymbols.selected),
                    tooltip: l10n.gymConfirm,
                    onPressed: onConfirm,
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A why-not line under a form (Swift `InlineMessage(.info, …)`).
class GymFormMessage extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => AppInlineMessage(
    kind: AppInlineMessageKind.info,
    text: text,
    kindLabel: context.l10n.gymInfo,
  );
}

/// Plays the success haptic, as Swift does after an add.
void gymSaved() => unawaited(HapticFeedback.successNotification());
