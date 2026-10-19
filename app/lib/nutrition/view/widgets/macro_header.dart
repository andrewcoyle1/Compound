import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:compound_maths/compound_maths.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// How each [Macro] is labelled and coloured, wherever it is drawn.
extension MacroStyle on Macro {
  /// The macro's short name.
  String label(AppLocalizations l10n) => switch (this) {
    Macro.calories => l10n.nutritionMacroCalories,
    Macro.fat => l10n.nutritionMacroFat,
    Macro.protein => l10n.nutritionMacroProtein,
    Macro.carbs => l10n.nutritionMacroCarbs,
  };

  /// The macro's data colour.
  Color colour(AppColors colors) => switch (this) {
    Macro.calories => colors.calories,
    Macro.fat => colors.fat,
    Macro.protein => colors.protein,
    Macro.carbs => colors.carbs,
  };

  /// The macro's glyph.
  IconData get icon => switch (this) {
    Macro.calories => AppSymbols.calories,
    Macro.fat => AppSymbols.fat,
    Macro.protein => AppSymbols.protein,
    Macro.carbs => AppSymbols.carbs,
  };

  /// Whether [settings] asks for this macro's bar.
  bool isShown(FoodLogSettings settings) => switch (this) {
    Macro.calories => settings.showCaloriesRing,
    Macro.fat => settings.showFatRing,
    Macro.protein => settings.showProteinRing,
    Macro.carbs => settings.showCarbsRing,
  };
}

/// The day's calories and macros against its target (Swift `MacroHeader`):
/// a bar per macro the settings show, on two pages, what has been eaten and
/// what is left. A tap or a swipe turns the page.
class MacroHeader extends StatefulWidget {
  const new({
    required this.totals,
    required this.target,
    required this.settings,
    super.key,
  });

  /// What the day's meals add up to.
  final Macros totals;

  /// The plan's target for the day.
  final Macros target;

  /// Which bars to show, and whether the remaining page goes below zero.
  final FoodLogSettings settings;

  @override
  State<MacroHeader> createState() => _MacroHeaderState();
}

class _MacroHeaderState extends State<MacroHeader> {
  bool _remaining = false;

  void _toggle() => setState(() => _remaining = !_remaining);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final macros = [
      for (final macro in Macro.values)
        if (macro.isShown(widget.settings)) macro,
    ];
    if (macros.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      onTapHint: _remaining
          ? l10n.nutritionMacroHeaderShowConsumed
          : l10n.nutritionMacroHeaderShowRemaining,
      onTap: _toggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) != 0) _toggle();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: Column(
            spacing: AppSpacing.xs,
            children: [
              Row(
                spacing: AppSpacing.m,
                children: [
                  for (final macro in macros)
                    Expanded(
                      child: _MacroBar(
                        macro: macro,
                        total: macro.of(widget.totals),
                        target: macro.of(widget.target),
                        remaining: _remaining,
                        showOverages: widget.settings.showOverages,
                      ),
                    ),
                ],
              ),
              ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: AppSpacing.xs,
                  children: [
                    for (final page in [false, true])
                      DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: const CircleBorder(),
                          color: page == _remaining
                              ? scheme.onSurfaceVariant
                              : scheme.outlineVariant,
                        ),
                        child: const SizedBox.square(dimension: AppSpacing.xs),
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

class _MacroBar extends StatelessWidget {
  const new({
    required this.macro,
    required this.total,
    required this.target,
    required this.remaining,
    required this.showOverages,
  });

  final Macro macro;
  final double total;
  final double target;
  final bool remaining;
  final bool showOverages;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colour = macro.colour(context.appColors);
    final left = macroRemaining(
      total: total,
      target: target,
      showOverages: showOverages,
    );
    // Whole numbers, cut rather than rounded, as the Swift header prints.
    final figure = remaining
        ? l10n.nutritionMacroLeft(AppFormat.number(left.truncate()))
        : l10n.nutritionMacroConsumed(
            AppFormat.number(total.truncate()),
            AppFormat.number(target.truncate()),
          );
    return Semantics(
      label: macro.label(l10n),
      value: figure,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xxs,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              spacing: AppSpacing.xxs,
              children: [
                Icon(
                  macro.icon,
                  color: colour,
                  size: MediaQuery.textScalerOf(context)
                      .scale(AppTextStyles.label.fontSize!),
                ),
                Text(
                  figure,
                  style: AppTextStyles.label.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          // The bar drains on the remaining page, so it agrees with the
          // figure above it.
          BulletBar(
            value: macroProgress(remaining ? left : total, target),
            thickness: AppChartMark.bulletWidthSmall,
            color: colour,
          ),
        ],
      ),
    );
  }
}
