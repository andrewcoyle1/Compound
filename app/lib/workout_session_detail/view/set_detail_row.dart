import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound_models/compound_models.dart';

/// One logged set on the session detail: its number (a pair shares one and
/// is told apart by L or R), what was done in the exercise's own terms, RPE,
/// and markers for a warm-up and for a set performed another way. A drop or
/// mini-set is indented under its set instead of numbered. A port of the
/// Swift app's `SetDetailRow`.
class SetDetailRow extends StatelessWidget {
  const new({
    required this.set,
    required this.number,
    required this.trackingMode,
    required this.weightUnit,
    required this.distanceUnit,
    super.key,
  });

  /// The set.
  final WorkoutSetModel set;

  /// The number it is shown as, from `workingSetNumber`.
  final int number;

  /// How its exercise is tracked.
  final TrackingMode trackingMode;

  /// The exercise's weight unit.
  final ExerciseWeightUnit weightUnit;

  /// The distance unit.
  final AppDistanceUnit distanceUnit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final secondary = AppTextStyles.rowDetail.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final value = WorkoutText.setValue(
      l10n,
      set,
      trackingMode,
      weightUnit: weightUnit,
      distanceUnit: distanceUnit,
      locale: locale,
    );
    final rpe = set.rpe;
    final kind = WorkoutText.setKind(l10n, set.kind);

    final Widget? label;
    if (set.isWarmup) {
      label = null;
    } else if (set.isSubSet) {
      label = Icon(
        AppSymbols.subSet,
        size: AppIconSize.small.of(context),
        color: scheme.onSurfaceVariant,
      );
    } else {
      final side = switch (set.side) {
        SetSide.left => 'L',
        SetSide.right => 'R',
        _ => '',
      };
      label = Text(
        l10n.setLabel(AppFormat.number(number, locale: locale), side),
        style: secondary,
      );
    }

    final markers = [
      if (rpe != null)
        Text(
          l10n.setRpe(
            AppFormat.number(rpe, maxFractionDigits: 1, locale: locale),
          ),
          style: AppTextStyles.label.copyWith(color: scheme.onSurfaceVariant),
        ),
      if (kind != null) AppChip(label: kind),
      if (set.isWarmup)
        AppChip(
          label: l10n.setWarmup,
          icon: AppSymbols.warmup,
          tint: colors.warmup,
        ),
    ];
    final valueText = value == null
        ? null
        : Text(
            value,
            style: AppTextStyles.rowDetail.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );

    final isLargeText =
        MediaQuery.textScalerOf(context).scale(1) >=
        AppListRow.accessibilityTextScale;
    final content = isLargeText
        ? Wrap(
            spacing: AppSpacing.m,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [?label, ?valueText, ...markers],
          )
        : Row(
            spacing: AppSpacing.m,
            children: [
              ?label,
              Expanded(child: valueText ?? const SizedBox.shrink()),
              ...markers,
            ],
          );

    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppControlSize.row),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: set.isSubSet ? AppSpacing.xl : AppSpacing.l,
            end: AppSpacing.l,
            top: AppSpacing.s,
            bottom: AppSpacing.s,
          ),
          child: content,
        ),
      ),
    );
  }
}
