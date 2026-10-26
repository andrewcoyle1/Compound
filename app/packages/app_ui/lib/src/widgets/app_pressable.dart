import 'dart:async';
import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:flutter/rendering.dart';

/// {@template app_pressable}
/// Makes [child] a tap target: the app's one pressed state (Material ink
/// on the nearest surface, clipped to [shape]), an optional [haptic] on
/// tap, and a button to screen readers while [onTap] is set.
///
/// The target is at least 44 × 44 pt. A smaller [child] keeps its size and
/// is centred in the larger target, which takes a press anywhere on it.
///
/// With a [color], it draws its own surface in [shape] behind [child], such
/// as a keypad key; without one, the ink draws on the card or sheet below.
///
/// For a row, a card or a button, use the `app_ui` widget made for it. A
/// drag, pinch or swipe is a gesture, not a press: use a `GestureDetector`
/// for those.
/// {@endtemplate}
class AppPressable extends StatelessWidget {
  /// {@macro app_pressable}
  const new({
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.haptic,
    this.shape,
    this.color,
    super.key,
  });

  /// Called when tapped. With [onLongPress] also `null`, nothing responds.
  final VoidCallback? onTap;

  /// Called on a long press, such as to open a menu.
  final VoidCallback? onLongPress;

  /// Played before [onTap], such as [AppHaptic.selection] for a choice.
  final AppHaptic? haptic;

  /// The pressed state's outline, and the surface's when [color] is set. A
  /// rectangle by default.
  final ShapeBorder? shape;

  /// The surface drawn behind [child], from `appColors` or the
  /// `ColorScheme`.
  final Color? color;

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    final haptic = this.haptic;
    Widget target = InkWell(
      onTap: onTap == null || haptic == null
          ? onTap
          : () {
              unawaited(AppHaptics.play(haptic));
              onTap();
            },
      onLongPress: onLongPress,
      customBorder: shape,
      child: child,
    );
    final color = this.color;
    if (color != null) {
      target = Material(
        color: color,
        shape: shape,
        clipBehavior: shape == null ? Clip.none : Clip.antiAlias,
        child: target,
      );
    }
    return _MinimumTarget(
      child: Semantics(button: onTap != null, child: target),
    );
  }
}

/// At least [AppControlSize.row] square, [child] centred in it at its own
/// size; a press in the margin goes to [child] (as Material's padded tap
/// targets do).
class _MinimumTarget extends SingleChildRenderObjectWidget {
  const new({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMinimumTarget();
}

class _RenderMinimumTarget extends RenderShiftedBox {
  new() : super(null);

  static const double _side = AppControlSize.row;

  Size _grow(Size size) =>
      Size(math.max(size.width, _side), math.max(size.height, _side));

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(super.computeMinIntrinsicWidth(height), _side);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.max(super.computeMaxIntrinsicWidth(height), _side);

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(super.computeMinIntrinsicHeight(width), _side);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(super.computeMaxIntrinsicHeight(width), _side);

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(_grow(child!.getDryLayout(constraints)));

  @override
  void performLayout() {
    final child = this.child!..layout(constraints, parentUsesSize: true);
    size = constraints.constrain(_grow(child.size));
    (child.parentData! as BoxParentData).offset = Alignment.center.alongOffset(
      size - child.size as Offset,
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (super.hitTest(result, position: position)) return true;
    if (!size.contains(position)) return false;
    final child = this.child!;
    final center = child.size.center(Offset.zero);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(center),
      position: center,
      hitTest: (result, position) => child.hitTest(result, position: center),
    );
  }
}
