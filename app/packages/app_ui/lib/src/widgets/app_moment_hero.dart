import 'package:app_ui/app_ui.dart';

/// How much of a show an [AppMomentHero] puts on (design-language.md,
/// "Motion").
enum AppMomentCelebration {
  /// None: the number as it is, for a screen that only reports, such as a
  /// past workout or a week that missed its goal.
  none,

  /// The number counts up, the badge flashes on, and a success haptic
  /// plays as it lands: a personal record, a goal ring closing.
  moment,

  /// A [moment] with confetti: the big ones, such as a workout finished or
  /// a weekly goal met.
  confetti,
}

/// One figure under an [AppMomentHero]'s number: its `value` over its
/// `label`, which is shown upper-cased.
typedef AppMomentStat = ({String value, String label});

/// {@template app_moment_hero}
/// The full-bleed hero of a Moment screen (design-language.md, "Screen
/// types"): the achievement as one huge number, with its details as a list
/// below it on the screen.
///
/// From the top: an optional [badge] as a volt chip (the accent means
/// "you"), [value] in [AppTextStyles.hero], its [label] as an overline with
/// an optional [info] button, one line of [caption], and up to a few
/// [stats], each a number over an overline.
///
/// With a [celebration], the number counts up from zero over
/// [AppMotion.emphasis], the badge pops on, a success haptic plays as the
/// count lands, and for [AppMomentCelebration.confetti] confetti bursts
/// from the number. A later [value] counts from the one shown. Reduce
/// Motion leaves the final state and the haptic.
///
/// [format] writes a value as shown, such as `AppFormat.number`; while
/// counting it is given whole numbers, and at the end [value] itself.
/// Screen readers hear the whole hero once, with the final number:
/// "badge, value, label, caption". [info] and each stat are their own
/// elements.
/// {@endtemplate}
class AppMomentHero extends StatefulWidget {
  /// {@macro app_moment_hero}
  const new({
    required this.value,
    required this.format,
    required this.label,
    this.badge,
    this.badgeIcon = AppSymbols.success,
    this.caption,
    this.info,
    this.stats = const [],
    this.celebration = AppMomentCelebration.moment,
    super.key,
  });

  /// The achievement, such as the kilograms lifted.
  final num value;

  /// Writes a value as shown, such as `12,450`.
  final String Function(num value) format;

  /// What [value] counts, such as `kg lifted`: shown upper-cased.
  final String label;

  /// What was earned, such as `Workout Complete`, in a volt chip.
  final String? badge;

  /// The [badge]'s glyph.
  final IconData badgeIcon;

  /// One line under the label, such as the workout's name.
  final String? caption;

  /// An info button beside the label, such as a method's ⓘ.
  final Widget? info;

  /// The figures under the hero.
  final List<AppMomentStat> stats;

  /// How much of a show it puts on.
  final AppMomentCelebration celebration;

  @override
  State<AppMomentHero> createState() => _AppMomentHeroState();
}

class _AppMomentHeroState extends State<AppMomentHero> {
  bool _landed = false;

  bool get _celebrates => widget.celebration != AppMomentCelebration.none;

  /// The success haptic, once, as the first count lands.
  void _land() {
    if (_landed || !_celebrates) return;
    _landed = true;
    AppHaptics.play(AppHaptic.success).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value.toDouble();
    final badge = widget.badge;
    final caption = widget.caption;
    final info = widget.info;
    final duration = _celebrates
        ? AppMotion.emphasis.durationOf(context)
        : Duration.zero;
    final secondaryOverline = AppTextStyles.overline.secondary(context);
    final scaler = MediaQuery.textScalerOf(context);
    final stacked =
        scaler.scale(AppTextStyles.rowTitle.fontSize!) >=
        AppTextStyles.rowTitle.fontSize! * AppListRow.accessibilityTextScale;
    Widget figure(AppMomentStat stat) => Semantics(
      container: true,
      label: stat.label,
      value: stat.value,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xxs,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(stat.value, style: AppTextStyles.metricLarge),
          ),
          Text(
            stat.label.toUpperCase(),
            textAlign: TextAlign.center,
            style: secondaryOverline,
          ),
        ],
      ),
    );

    final number = TweenAnimationBuilder<double>(
      tween: Tween(begin: _celebrates ? 0 : value, end: value),
      duration: duration,
      // No overshoot: a count past the final number would misread it.
      curve: Curves.easeOutCubic,
      onEnd: _land,
      builder: (context, shown, _) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          widget.format(shown == value ? widget.value : shown.round()),
          maxLines: 1,
          // A taller line than a dashboard's hero: a unit's descender
          // ("kg") must clear the label under it.
          style: AppTextStyles.hero.copyWith(height: 1.2),
        ),
      ),
    );

    final label = ExcludeSemantics(
      child: Text(
        widget.label.toUpperCase(),
        textAlign: TextAlign.center,
        style: secondaryOverline,
      ),
    );
    // Read as one element; only the info button keeps its own.
    final hero = Semantics(
      container: true,
      label: [
        ?badge,
        widget.format(widget.value),
        widget.label,
        ?caption,
      ].join(', '),
      child: Column(
        spacing: AppSpacing.xs,
        children: [
          if (badge != null)
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: _celebrates ? 0 : 1, end: 1),
                  duration: duration,
                  curve: AppMotion.emphasis.curve,
                  builder: (context, t, child) => Opacity(
                    opacity: t.clamp(0, 1).toDouble(),
                    child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
                  ),
                  child: AppChip(
                    label: badge,
                    icon: widget.badgeIcon,
                    selected: true,
                    size: AppChipSize.large,
                  ),
                ),
              ),
            ),
          // As a large title does, it stops growing at 150%.
          ExcludeSemantics(
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: AppScaffold.largeTitleMaxTextScale,
              child: AppConfetti(
                playsOnMount:
                    widget.celebration == AppMomentCelebration.confetti,
                play: widget.celebration == AppMomentCelebration.confetti,
                child: number,
              ),
            ),
          ),
          if (info == null)
            label
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: label),
                Semantics(container: true, child: info),
              ],
            ),
          if (caption != null)
            ExcludeSemantics(
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: AppTextStyles.rowDetail.secondary(context),
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.l,
        children: [
          hero,
          // Side by side in equal columns, each number shrinking to fit
          // its own; at accessibility sizes they wrap instead, at full
          // size.
          if (widget.stats.isNotEmpty && stacked)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.m,
              children: [for (final stat in widget.stats) figure(stat)],
            )
          else if (widget.stats.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.s,
              children: [
                for (final stat in widget.stats) Expanded(child: figure(stat)),
              ],
            ),
        ],
      ),
    );
  }
}
