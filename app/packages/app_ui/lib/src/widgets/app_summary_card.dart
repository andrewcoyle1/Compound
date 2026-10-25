import 'dart:async';

import 'package:app_ui/app_ui.dart';

/// {@template app_summary_card}
/// A summary at a glance (design-language.md, "Components"): a header, a
/// hero and an optional footer, on an [AppCard].
///
/// - **Header:** [icon] in its data colour ([tint]), [title] as an
///   overline, and an optional [trailing] [AppChip] or info button. A
///   chevron follows when the card opens something.
/// - **Hero:** [value] in the display face, with an optional [unit] after
///   it and at most one [delta]; and/or a [chart] (a chart, a ring, any
///   widget), under the number or, with [chartBeside], beside it.
/// - **Footer:** one line of secondary text.
///
/// With [onTap] the whole card is one button: one pressed state, one
/// haptic and a chevron, with no buttons inside but [trailing]. Without it
/// the card only shows. Screen readers read it as one element, "title,
/// value unit, delta, footer"; give [semanticValue] when the hero is a
/// [chart] without a [value].
///
/// A goal the user hit shows the accent as a volt fill: pass a selected
/// [AppChip] as the [delta], or a ring filled in volt as the [chart].
/// [prominent] draws [value] in [AppTextStyles.display], for the one hero
/// card at the top of a dashboard; otherwise it is
/// [AppTextStyles.metricLarge].
///
/// At accessibility text sizes a chart beside the number moves under it,
/// and the delta wraps under the number, so nothing clips.
/// {@endtemplate}
class AppSummaryCard extends StatelessWidget {
  /// {@macro app_summary_card}
  const new({
    required this.title,
    this.icon,
    this.tint,
    this.value,
    this.unit,
    this.delta,
    this.chart,
    this.chartBeside = false,
    this.footer,
    this.trailing,
    this.onTap,
    this.prominent = false,
    this.semanticValue,
    super.key,
  });

  /// What the card sums up, such as "Protein": shown upper-cased.
  final String title;

  /// The header's glyph, from [AppSymbols].
  final IconData? icon;

  /// The data colour of [icon]. Without it the icon is secondary.
  final Color? tint;

  /// The hero number, formatted, such as `104 / 165`.
  final String? value;

  /// The unit after [value], such as `g`: shown upper-cased.
  final String? unit;

  /// The one change or status beside the number: an [AppChip], selected
  /// (volt) for a goal hit.
  final AppChip? delta;

  /// A chart, ring or other widget: the hero itself, or with [value]
  /// under or beside it. Its own semantics are left out.
  final Widget? chart;

  /// Whether [chart] sits at the number's trailing side, as a ring does,
  /// rather than under it.
  final bool chartBeside;

  /// One line of secondary text under the hero.
  final String? footer;

  /// An [AppChip] or info button at the header's trailing edge.
  final Widget? trailing;

  /// Makes the whole card a button.
  final VoidCallback? onTap;

  /// Whether [value] is the screen's hero, in the display style.
  final bool prominent;

  /// What screen readers hear for the hero when it has no [value].
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final scaler = MediaQuery.textScalerOf(context);
    final icon = this.icon;
    final value = this.value;
    final unit = this.unit;
    final delta = this.delta;
    final chart = this.chart;
    final footer = this.footer;
    final trailing = this.trailing;
    final onTap = this.onTap;
    // As tall as the overline's line, so the glyph is no bigger than the
    // title beside it.
    final glyph = scaler.scale(
      AppTextStyles.overline.fontSize! * AppTextStyles.overline.height!,
    );

    final header = Row(
      spacing: AppSpacing.s,
      children: [
        Expanded(
          child: ExcludeSemantics(
            child: Row(
              spacing: AppSpacing.s,
              children: [
                if (icon != null)
                  Icon(icon, size: glyph, color: tint ?? colors.secondaryLabel),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: AppTextStyles.overline.secondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (trailing != null) Semantics(container: true, child: trailing),
        if (onTap != null)
          ExcludeSemantics(
            child: Icon(
              AppSymbols.disclosure,
              size: glyph,
              color: scheme.outline,
            ),
          ),
      ],
    );

    final number = value == null
        ? null
        : Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  text: value,
                  style: prominent
                      ? AppTextStyles.display
                      : AppTextStyles.metricLarge,
                  children: [
                    if (unit != null)
                      TextSpan(
                        text: ' ${unit.toUpperCase()}',
                        style: AppTextStyles.overline.secondary(context),
                      ),
                  ],
                ),
              ),
              ?delta,
            ],
          );
    final stacked =
        scaler.scale(AppTextStyles.rowTitle.fontSize!) >=
        AppTextStyles.rowTitle.fontSize! * AppListRow.accessibilityTextScale;
    final hero = switch ((number, chart)) {
      (null, null) => null,
      (final number?, null) => number,
      // Left at its own size: a ring stays round.
      (null, final chart?) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: chart,
      ),
      (final number?, final chart?) when chartBeside && !stacked => Row(
        spacing: AppSpacing.l,
        children: [
          Expanded(child: number),
          chart,
        ],
      ),
      (final number?, final chart?) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.m,
        children: [number, chart],
      ),
    };

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.m,
        children: [
          header,
          if (hero != null) ExcludeSemantics(child: hero),
          if (footer != null)
            ExcludeSemantics(
              child: Text(
                footer,
                style: AppTextStyles.rowDetail.secondary(context),
              ),
            ),
        ],
      ),
    );

    final heard = [
      [?value, ?unit].join(' '),
      if (value == null) ?semanticValue,
      ?delta?.label,
      ?footer,
    ].where((part) => part.isNotEmpty).join(', ');
    return AppCard(
      child: Semantics(
        container: true,
        button: onTap != null,
        label: title,
        value: heard,
        // Everything but the trailing chip or button is read from here;
        // that keeps its own node, so it stays reachable.
        child: onTap == null
            ? content
            : InkWell(
                onTap: () {
                  unawaited(AppHaptics.light());
                  onTap();
                },
                child: content,
              ),
      ),
    );
  }
}
