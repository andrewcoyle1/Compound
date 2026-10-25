import 'package:app_ui/app_ui.dart';

/// {@template app_selection_ring}
/// [child] with a grid cell's or swatch's selection mark: a ring in the
/// accent ([AppColors.accentInk]) over its edge while [selected], such as
/// the chosen photo, muscle or day.
///
/// The ring is the second cue, never the only one: the caller's
/// `Semantics(selected:)` tells screen readers.
///
/// [radius] rounds the ring to the cell's corners, with continuous corners
/// as [AppCard] has; without one the ring is a circle. [filled] sets the
/// cell on `raised`, as a control on a surface.
/// {@endtemplate}
class AppSelectionRing extends StatelessWidget {
  /// {@macro app_selection_ring}
  const new({
    required this.selected,
    required this.child,
    this.radius,
    this.filled = false,
    super.key,
  });

  /// The ring's width.
  static const double width = 3;

  /// Whether the ring shows.
  final bool selected;

  /// The cell.
  final Widget child;

  /// The cell's corner radius, an [AppRadius]; null for a circle.
  final double? radius;

  /// Whether the cell is drawn on `raised`.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final radius = this.radius;
    final shape = radius == null
        ? const CircleBorder()
        : RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          );
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: shape.copyWith(
          side: selected
              ? BorderSide(color: context.appColors.accentInk, width: width)
              : BorderSide.none,
        ),
      ),
      child: filled
          ? DecoratedBox(
              decoration: ShapeDecoration(
                shape: shape,
                color: context.appColors.raised,
              ),
              child: child,
            )
          : child,
    );
  }
}
