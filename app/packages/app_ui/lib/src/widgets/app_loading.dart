import 'package:app_ui/app_ui.dart';

/// {@template app_loading_view}
/// A centred spinner for a whole screen's first load, and only that: a list
/// or card that is loading shows [AppPlaceholderRow]s or [AppPlaceholder]s
/// shaped like its content instead. Screen readers hear [label].
/// {@endtemplate}
class AppLoadingView extends StatelessWidget {
  /// {@macro app_loading_view}
  const new({required this.label, super.key});

  /// What screen readers hear, localized, such as "Loading".
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: label,
      liveRegion: true,
      child: const CircularProgressIndicator.adaptive(),
    ),
  );
}

/// {@template app_placeholder}
/// A grey rounded shape standing in for content that is still loading
/// (Swift's `.redacted(reason: .placeholder)`). It holds still, as
/// Swift's does, so it never keeps a test from settling.
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
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: true,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
      ),
      child: SizedBox(width: width, height: height),
    ),
  );
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
