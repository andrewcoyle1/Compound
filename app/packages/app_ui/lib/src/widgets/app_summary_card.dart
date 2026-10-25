import 'package:app_ui/app_ui.dart';

/// How loud an [AppSummaryCard]'s number is.
enum AppSummaryCardSize {
  /// [AppTextStyles.metricLarge], the unit after the number: a summary
  /// among others.
  regular,

  /// [AppTextStyles.display], the unit under the number: a card that
  /// carries a headline figure, such as a streak.
  large,

  /// [AppTextStyles.hero], the unit under the number: the one hero card at
  /// the top of a dashboard, the loudest thing on the screen.
  hero;

  TextStyle get _style => switch (this) {
    regular => AppTextStyles.metricLarge,
    large => AppTextStyles.display,
    hero => AppTextStyles.hero,
  };
}

/// {@template app_summary_card}
/// A summary at a glance (design-language.md, "Components"): a header, a
/// hero and an optional footer, on an [AppCard].
///
/// - **Header:** [icon] in its data colour ([tint]), [title] as an
///   overline, and an optional [trailing] [AppChip] or info button. A
///   chevron follows when the card opens something.
/// - **Hero:** [value] in the display face at [size], with an optional
///   [unit] and at most one [delta]; and/or a [chart] (a chart, a ring,
///   any widget), under the number or, with [chartBeside], beside it.
/// - **Footer:** one line of secondary text.
/// - **Rows:** optionally, the rows the hero sums up, under it on the same
///   card with hairlines between them, such as a day's checklist under
///   its count. Only on a card without [onTap].
/// - **Actions:** optionally, the buttons that act on what the card shows,
///   such as a workout's Start and Skip, at its foot. They sit outside the
///   card's own tap target, so each stays its own button.
///
/// With [onTap] the whole card is one button: one pressed state, one
/// haptic and a chevron, with no buttons inside but [trailing]. Without it
/// the card only shows. Screen readers read the summary as one element,
/// "title, value unit, delta, footer"; give [semanticValue] when the hero
/// is a [chart] without a [value]. [trailing] and each of [rows] stay
/// their own elements.
///
/// A goal the user hit shows the accent as a volt fill: pass a selected
/// [AppChip] as the [delta], or a ring filled in volt as the [chart].
///
/// At accessibility text sizes a chart beside the number moves under it,
/// and the delta wraps under the number, so nothing clips. A
/// [AppSummaryCardSize.hero] number stops growing at 150%, as a large
/// title does.
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
    this.size = AppSummaryCardSize.regular,
    this.semanticValue,
    this.rows = const [],
    this.actions,
    super.key,
  }) : assert(onTap == null || rows.length == 0, 'A button has no rows');

  /// What the card sums up, such as "Protein": shown upper-cased.
  final String title;

  /// The header's glyph, from [AppSymbols].
  final IconData? icon;

  /// The data colour of [icon]. Without it the icon is secondary.
  final Color? tint;

  /// The hero number, formatted, such as `104 / 165`.
  final String? value;

  /// The unit of [value], such as `g`: shown upper-cased.
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

  /// How loud [value] is.
  final AppSummaryCardSize size;

  /// What screen readers hear for the hero when it has no [value].
  final String? semanticValue;

  /// The rows the hero sums up, usually `AppListRowButton`s.
  final List<Widget> rows;

  /// The buttons at the card's foot, usually [AppCtaButton]s in
  /// [AppCtaSize.compact] laid out in a row or a wrap.
  final Widget? actions;

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
    final actions = this.actions;
    // As tall as the overline's line, so the glyph is no bigger than the
    // title beside it.
    final glyph = scaler.scale(
      AppTextStyles.overline.fontSize! * AppTextStyles.overline.height!,
    );
    final secondaryOverline = AppTextStyles.overline.secondary(context);
    // At accessibility sizes there is no room across: a chart beside the
    // number moves under it, and the header's chip or button under the
    // title.
    final stacked =
        scaler.scale(AppTextStyles.rowTitle.fontSize!) >=
        AppTextStyles.rowTitle.fontSize! * AppListRow.accessibilityTextScale;

    final titleRow = Row(
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
                  child: Text(title.toUpperCase(), style: secondaryOverline),
                ),
              ],
            ),
          ),
        ),
        if (trailing != null && !stacked)
          Semantics(container: true, child: trailing),
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
    final header = trailing != null && stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.xs,
            children: [
              titleRow,
              Semantics(container: true, child: trailing),
            ],
          )
        : titleRow;

    Widget? number;
    if (value != null) {
      // A summary among others reads "104 / 165 G" on one line; a louder
      // number stands over its unit, as a stat does.
      final stat = switch (size) {
        AppSummaryCardSize.regular => Text.rich(
          TextSpan(
            text: value,
            style: size._style,
            children: [
              if (unit != null)
                TextSpan(
                  text: ' ${unit.toUpperCase()}',
                  style: secondaryOverline,
                ),
            ],
          ),
        ),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (size == AppSummaryCardSize.hero)
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: AppScaffold.largeTitleMaxTextScale,
                child: Text(value, style: size._style),
              )
            else
              Text(value, style: size._style),
            if (unit != null)
              Text(unit.toUpperCase(), style: secondaryOverline),
          ],
        ),
      };
      number = Wrap(
        spacing: AppSpacing.m,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [stat, ?delta],
      );
    }
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
    // Everything but the trailing chip or button is read from one node;
    // that keeps its own, so it stays reachable. As a button, the node is
    // the pressable's, which carries the tap.
    final summary = onTap == null
        ? Semantics(container: true, label: title, value: heard, child: content)
        : AppPressable(
            onTap: onTap,
            haptic: AppHaptic.light,
            child: Semantics(label: title, value: heard, child: content),
          );
    return AppCard(
      child: rows.isEmpty && actions == null
          ? summary
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                summary,
                for (final (index, row) in rows.indexed) ...[
                  Divider(
                    indent: index == 0
                        ? 0
                        : AppSection.dividerIndent(rows[index - 1], scaler),
                  ),
                  row,
                ],
                if (actions != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.l,
                      0,
                      AppSpacing.l,
                      AppSpacing.l,
                    ),
                    child: actions,
                  ),
              ],
            ),
    );
  }
}
