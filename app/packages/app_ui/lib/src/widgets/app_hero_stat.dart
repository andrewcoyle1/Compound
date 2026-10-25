import 'package:app_ui/app_ui.dart';

/// {@template app_hero_stat}
/// A Detail screen's hero (design-language.md, "Screen types"): the one
/// number the screen is about, on the canvas over its chart.
///
/// - [label] as an overline, after an optional [leading] key (a chart
///   series' swatch);
/// - [value] in [AppTextStyles.hero], with [unit] as an overline under it
///   and at most one [delta] beside it, an [AppChip] such as "−0.4 kg";
/// - [caption], one line of secondary text, such as the dates the figure
///   covers.
///
/// Screen readers read it as one element, "label, value unit, delta,
/// caption". The number stops growing at 150%, as a large title does,
/// shrinks to fit rather than break when it is still too wide, and the
/// delta wraps under it when there is no room beside it.
/// {@endtemplate}
class AppHeroStat extends StatelessWidget {
  /// {@macro app_hero_stat}
  const new({
    required this.value,
    this.label,
    this.leading,
    this.unit,
    this.delta,
    this.caption,
    super.key,
  });

  /// The number, formatted, such as `82.4`.
  final String value;

  /// What the number is, such as "Average": shown upper-cased.
  final String? label;

  /// A key before [label], such as a chart series' swatch.
  final Widget? leading;

  /// The unit of [value], such as `kg`: shown upper-cased.
  final String? unit;

  /// The one change beside the number.
  final AppChip? delta;

  /// One line under the number, such as the dates it covers.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    final leading = this.leading;
    final unit = this.unit;
    final delta = this.delta;
    final caption = this.caption;
    final overline = AppTextStyles.overline.secondary(context);
    final heard = [
      [value, ?unit].join(' '),
      ?delta?.label,
      ?caption,
    ].join(', ');
    return Semantics(
      container: true,
      label: label,
      value: heard,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xxs,
        children: [
          if (label != null)
            Row(
              spacing: AppSpacing.s,
              children: [
                ?leading,
                Flexible(child: Text(label.toUpperCase(), style: overline)),
              ],
            ),
          Wrap(
            spacing: AppSpacing.m,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shrinks rather than breaks a long number ("12,450") at
                  // large text.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: AppScaffold.largeTitleMaxTextScale,
                      child: Text(value, style: AppTextStyles.hero),
                    ),
                  ),
                  if (unit != null) Text(unit.toUpperCase(), style: overline),
                ],
              ),
              ?delta,
            ],
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                caption,
                style: AppTextStyles.rowDetail.secondary(context),
              ),
            ),
        ],
      ),
    );
  }
}
