import 'package:app_ui/app_ui.dart';

/// {@template app_icon_badge}
/// A glyph in a circle, standing in for a picture: a logged food without a
/// photo (Swift's `fork.knife.circle.fill`), or an image a form has yet to
/// be given (`fork.knife.circle`). Decorative, so screen readers skip it.
///
/// [filled] draws a solid circle in the secondary colour with the glyph cut
/// out of it; otherwise a ring and the glyph in a fainter tone. [badge] adds
/// a small filled circle at the bottom trailing corner, such as a pencil on
/// an image that can be changed.
///
/// [size] is the circle's diameter at the default text size; it grows with
/// the text, as icons do.
/// {@endtemplate}
class AppIconBadge extends StatelessWidget {
  /// {@macro app_icon_badge}
  const new({
    required this.icon,
    this.size = AppIconSize.medium,
    this.filled = true,
    this.badge,
    super.key,
  });

  /// The glyph, from [AppSymbols].
  final IconData icon;

  /// The circle's diameter.
  final AppIconSize size;

  /// Whether the circle is solid, or a ring.
  final bool filled;

  /// A smaller glyph on a filled circle at the bottom trailing corner.
  final IconData? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surface = context.appColors.surface;
    final diameter = size.of(context);
    final tone = filled ? scheme.onSurfaceVariant : scheme.outline;
    final circle = DecoratedBox(
      decoration: ShapeDecoration(
        shape: CircleBorder(
          side: filled
              ? BorderSide.none
              : BorderSide(color: tone, width: diameter / 16),
        ),
        color: filled ? tone : null,
      ),
      child: SizedBox.square(
        dimension: diameter,
        child: Icon(
          icon,
          size: diameter * 0.55,
          color: filled ? surface : tone,
        ),
      ),
    );
    final badge = this.badge;
    return ExcludeSemantics(
      child: badge == null
          ? circle
          : Stack(
              clipBehavior: Clip.none,
              children: [
                circle,
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: CircleBorder(
                        side: BorderSide(color: surface, width: diameter / 32),
                      ),
                      color: scheme.onSurface,
                    ),
                    child: SizedBox.square(
                      dimension: diameter * 3 / 8,
                      child: Icon(badge, size: diameter * 0.22, color: surface),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
