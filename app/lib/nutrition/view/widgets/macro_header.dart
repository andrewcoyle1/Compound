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

/// The Nutrition tab's hero (Swift `MacroHeader`, as a dashboard card): the
/// day's calories in the largest number on the screen over a bar in their
/// colour, and a ring per macro in its own, each shown when the settings
/// ask for it. The header's chip, or a swipe, turns every figure
/// from what has been eaten to what is left, and back; a tap on the card
/// opens [onTap], the day's overview.
class NutritionHero extends StatefulWidget {
  const new({
    required this.totals,
    required this.target,
    required this.settings,
    this.onTap,
    super.key,
  });

  /// Whether [settings] leave the hero anything to show: a bar or a ring.
  static bool shows(FoodLogSettings settings) =>
      Macro.values.any((macro) => macro.isShown(settings));

  /// What the day's meals add up to.
  final Macros totals;

  /// The plan's target for the day.
  final Macros target;

  /// Which bar and rings to show, and whether what is left goes below
  /// zero.
  final FoodLogSettings settings;

  /// Opens the day's overview.
  final VoidCallback? onTap;

  @override
  State<NutritionHero> createState() => _NutritionHeroState();
}

class _NutritionHeroState extends State<NutritionHero> {
  bool _remaining = false;

  void _toggle() => setState(() => _remaining = !_remaining);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final settings = widget.settings;
    final eaten = widget.totals.calories;
    final target = widget.target.calories;
    final left = macroRemaining(
      total: eaten,
      target: target,
      showOverages: settings.showOverages,
    );
    // Whole numbers, cut rather than rounded, as the Swift header prints.
    final value = _remaining ? left.abs() : eaten;
    final unit = !_remaining
        ? l10n.nutritionHeroOf(AppFormat.kcal(target.truncate()))
        : left < 0
        ? l10n.nutritionHeroKcalOver
        : l10n.nutritionHeroKcalLeft;
    final rings = MacroRings(
      totals: widget.totals,
      target: widget.target,
      macros: [
        for (final macro in MacroRings.order)
          if (macro.isShown(settings)) macro,
      ],
      remaining: _remaining,
      showOverages: settings.showOverages,
    );
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) != 0) _toggle();
      },
      child: AppSummaryCard(
        title: l10n.nutritionOverviewCalories,
        icon: Macro.calories.icon,
        tint: colors.calories,
        size: AppSummaryCardSize.hero,
        value: AppFormat.number(value.truncate()),
        unit: unit,
        trailing: AppChip(
          label: _remaining
              ? l10n.nutritionHeroShowEaten
              : l10n.nutritionHeroShowLeft,
          icon: AppSymbols.swap,
          onPressed: _toggle,
        ),
        // The rings' figures are drawn, not read: the card reads them.
        semanticValue: rings.spoken(l10n),
        chart: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.xl,
          children: [
            // The bar drains on the remaining page, so it agrees with the
            // number above it.
            if (Macro.calories.isShown(settings))
              BulletBar(
                value: macroProgress(_remaining ? left : eaten, target),
                color: colors.calories,
              ),
            if (rings.macros.isNotEmpty) rings,
          ],
        ),
        onTap: widget.onTap,
      ),
    );
  }
}

/// The macros' rings side by side, each in its macro's colour: what has
/// been eaten (or, with [remaining], is left) in its middle, filling toward
/// the target, and its name and target under it. The Nutrition tab's hero
/// and the day's overview draw the same rings.
class MacroRings extends StatelessWidget {
  const new({
    required this.totals,
    required this.target,
    this.macros = order,
    this.remaining = false,
    this.showOverages = false,
    super.key,
  });

  /// The macros with grams, in the order they are drawn.
  static const List<Macro> order = [Macro.protein, Macro.carbs, Macro.fat];

  /// What the day's meals add up to.
  final Macros totals;

  /// The plan's target for the day.
  final Macros target;

  /// The rings to draw, from [order].
  final List<Macro> macros;

  /// Whether the rings show what is left rather than what has been eaten.
  final bool remaining;

  /// Whether what is left goes below zero.
  final bool showOverages;

  List<_MacroRing> get _rings => [
    for (final macro in macros)
      _MacroRing(
        macro: macro,
        total: macro.of(totals),
        target: macro.of(target),
        remaining: remaining,
        showOverages: showOverages,
      ),
  ];

  /// What a screen reader hears for the rings, which are drawn rather
  /// than read: "Protein, 104 of 165 g, Carbs, …".
  String spoken(AppLocalizations l10n) =>
      [for (final ring in _rings) ring.spoken(l10n)].join(', ');

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [for (final ring in _rings) Expanded(child: ring)],
  );
}

/// A macro's ring: what has been eaten (or is left) in its middle, filling
/// toward the target in the macro's colour, its name and target under it.
class _MacroRing extends StatelessWidget {
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

  double get _left =>
      macroRemaining(total: total, target: target, showOverages: showOverages);

  String _figure() =>
      AppFormat.number((remaining ? _left.abs() : total).truncate());

  String _detail(AppLocalizations l10n) => !remaining
      ? l10n.nutritionHeroOf(AppFormat.grams(target.truncate()))
      : _left < 0
      ? l10n.nutritionHeroGramsOver
      : l10n.nutritionHeroGramsLeft;

  /// What a screen reader hears for the ring: "Protein, 104 of 165 g".
  String spoken(AppLocalizations l10n) =>
      '${macro.label(l10n)}, ${_figure()} ${_detail(l10n)}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      spacing: AppSpacing.xs,
      children: [
        // The ring drains on the remaining page, as the bar does. Eaten
        // past the target, it laps itself, as Apple's Activity rings do.
        ProgressArc(
          value: remaining
              ? macroProgress(_left, target)
              : target > 0
              ? total / target
              : 0,
          color: macro.colour(context.appColors),
          diameter: AppControlSize.cta + AppSpacing.l,
          child: Text(_figure(), style: AppTextStyles.metric),
        ),
        Text(
          macro.label(l10n).toUpperCase(),
          style: AppTextStyles.overline,
          textAlign: TextAlign.center,
        ),
        Text(
          _detail(l10n),
          style: AppTextStyles.label.secondary(context),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
