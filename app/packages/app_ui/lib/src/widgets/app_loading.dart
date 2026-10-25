import 'package:app_ui/app_ui.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shimmer/shimmer.dart';

/// How big an [AppSpinner] is drawn.
enum AppSpinnerSize {
  /// [AppIconSize.small]: inside a button, a row's accessory or beside a
  /// line of text.
  small,

  /// [AppIconSize.medium]: on its own, for a screen or a section.
  regular,
}

/// {@template app_spinner}
/// The one activity indicator: twelve dots fading in turn around a circle,
/// in the accent (or [color]), the same on both platforms. It grows with
/// the text size.
///
/// Only the dots' opacity changes, nothing moves; with reduced motion
/// (`MediaQuery.disableAnimations`) they hold still, so it also never keeps
/// a test from settling. It is silent: [AppLoadingView], or the text beside
/// it, says what is loading.
/// {@endtemplate}
class AppSpinner extends StatelessWidget {
  /// {@macro app_spinner}
  const new({this.size = AppSpinnerSize.regular, this.color, super.key});

  /// How big it is drawn.
  final AppSpinnerSize size;

  /// The dots' colour; the accent when null. On a filled control, the
  /// control's foreground.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final spinner = ExcludeSemantics(
      // Shrinks to fit a slot smaller than its size, such as a toolbar's.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SpinKitFadingCircle(
          color: color ?? context.appColors.accentInk,
          size: switch (size) {
            AppSpinnerSize.small => AppIconSize.small,
            AppSpinnerSize.regular => AppIconSize.medium,
          }.of(context),
        ),
      ),
    );
    return TickerMode(
      enabled: !MediaQuery.disableAnimationsOf(context),
      child: spinner,
    );
  }
}

/// {@template app_loading_view}
/// A centred [AppSpinner] for a whole screen's first load, and only that: a
/// list or card that is loading shows [AppPlaceholderRow]s or
/// [AppPlaceholder]s shaped like its content instead. Screen readers hear
/// [label].
/// {@endtemplate}
class AppLoadingView extends StatelessWidget {
  /// {@macro app_loading_view}
  const new({required this.label, super.key});

  /// What screen readers hear, localized, such as "Loading".
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(label: label, liveRegion: true, child: const AppSpinner()),
  );
}

/// {@template app_placeholder}
/// A grey rounded shape standing in for content that is still loading
/// (Swift's `.redacted(reason: .placeholder)`), with a highlight sweeping
/// across it in the reading direction. With reduced motion
/// (`MediaQuery.disableAnimations`) it holds still, as Swift's does, which
/// also keeps it from stopping a test settling.
///
/// Give it the size of what it stands for: a line of text is as tall as the
/// text's line, a chart as tall as the chart. [width] defaults to the space
/// available. [AppPlaceholderRow] lays out a list row's worth.
///
/// Placeholders are silent to screen readers, except for one that carries
/// [semanticLabel]: give it to the first in a group, so "Loading" is heard
/// once.
/// {@endtemplate}
class AppPlaceholder extends StatelessWidget {
  /// {@macro app_placeholder}
  const new({
    required this.height,
    this.width,
    this.radius = AppRadius.s,
    this.semanticLabel,
    super.key,
  });

  /// The shape's height.
  final double height;

  /// The shape's width; the space available when null.
  final double? width;

  /// The corner radius: [AppRadius.s] for text, larger for a card or tile.
  final double radius;

  /// What screen readers hear, localized, such as "Loading".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    Widget shape = DecoratedBox(
      decoration: ShapeDecoration(
        color: base,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
      ),
      child: SizedBox(width: width, height: height),
    );
    if (!MediaQuery.disableAnimationsOf(context)) {
      shape = Shimmer.fromColors(
        baseColor: base,
        // Lighter than the shape in both modes: white in light, a lifted
        // grey in dark.
        highlightColor: scheme.surfaceBright,
        // The package's own pace, calmer than a one-second sweep.
        period: AppMotion.progress.duration * 1.5,
        direction: Directionality.of(context) == TextDirection.rtl
            ? ShimmerDirection.rtl
            : ShimmerDirection.ltr,
        child: shape,
      );
    }
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: shape,
    );
  }
}

/// {@template app_placeholder_row}
/// An [AppListRow]'s shape while it loads: an optional leading square, a
/// title line and an optional subtitle line, in [AppPlaceholder]s that grow
/// with the text size as the real row does. Put a few in the
/// [AppSection] that will hold the rows.
/// {@endtemplate}
class AppPlaceholderRow extends StatelessWidget {
  /// {@macro app_placeholder_row}
  const new({
    this.hasLeading = false,
    this.hasSubtitle = true,
    this.semanticLabel,
    super.key,
  });

  /// Whether the real row has an icon or thumbnail.
  final bool hasLeading;

  /// Whether the real row has a subtitle.
  final bool hasSubtitle;

  /// What screen readers hear; see [AppPlaceholder.semanticLabel].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle style) => scaler.scale(style.fontSize!);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppControlSize.listRow),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Row(
          spacing: AppSpacing.m,
          children: [
            if (hasLeading)
              AppPlaceholder(
                width: scaler.scale(AppControlSize.icon),
                height: scaler.scale(AppControlSize.icon),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xs,
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    child: AppPlaceholder(
                      height: line(AppTextStyles.rowTitle),
                      semanticLabel: semanticLabel,
                    ),
                  ),
                  if (hasSubtitle)
                    FractionallySizedBox(
                      widthFactor: 0.4,
                      child: AppPlaceholder(
                        height: line(AppTextStyles.rowDetail),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
