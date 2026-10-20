import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/gym_profiles/cubit/gym_profile_editor_cubit.dart';
import 'package:compound/gym_profiles/view/gym_text.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/workout_history/view/workout_text.dart';
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
  return showAppSheet<T>(
    context: context,
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
    // As wide as its two options need, wherever it sits.
    return IntrinsicWidth(
      child: AppSegmentedControl<ExerciseWeightUnit>(
        segments: [
          for (final unit in ExerciseWeightUnit.values)
            AppSegment(value: unit, label: WorkoutText.weightUnit(unit).symbol),
        ],
        selected: unit,
        onChanged: onChanged,
      ),
    );
  }
}

/// A list header with a trailing control, such as the unit switch, which
/// takes the width its options need and drops below the title when both
/// don't fit.
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
          IntrinsicWidth(child: trailing),
        ],
      ),
    );
  }
}

/// A row with Swift's swipe to delete (`onDelete`), which a screen reader
/// also offers as an action.
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
    return AppSwipeActions(
      key: ValueKey(id),
      trailing: [
        AppSwipeAction(
          label: context.l10n.gymDelete,
          icon: AppSymbols.delete,
          isDestructive: true,
          onPressed: onDelete,
        ),
      ],
      child: child,
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
    return AppEmptyState(
      icon: AppSymbols.equipment,
      title: l10n.gymNoUnitWeights(GymText.unitName(l10n, unit)),
      description: l10n.gymNoUnitWeightsMessage,
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
    return AppScaffold(
      appBar: AppBar(
        // Under the sheet's drag handle, not the status bar.
        primary: false,
        leading: AppToolbarButton.close(
          semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
        ),
        title: Semantics(
          header: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, textAlign: TextAlign.center),
              if (subtitle != null)
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.rowDetail.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (confirms)
            AppToolbarButton.confirm(
              semanticLabel: l10n.gymConfirm,
              onPressed: onConfirm,
            ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.m),
        itemBuilder: (_, index) => children[index],
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
void gymSaved() => unawaited(AppHaptics.success());
