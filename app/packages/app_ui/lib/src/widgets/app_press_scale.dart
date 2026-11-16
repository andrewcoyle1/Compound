import 'package:app_ui/app_ui.dart';
import 'package:flutter/rendering.dart';

/// {@template app_press_scale}
/// Shrinks a control to [AppPressScale.pressedScale] while it is pressed and
/// glides it back on release, over [AppMotion.press], so a press registers
/// before its result arrives.
///
/// [builder] hands the control a [WidgetStatesController] to pass to its
/// `InkWell` or button: the scale follows that control's own pressed state,
/// so a press that turns into a scroll lets go as the ink does.
///
/// Only small controls move: anything wider than [AppPressScale.maxWidth]
/// (a full-width button, a card, a row) keeps its highlight alone, because 4%
/// of a wide surface is a jump. Nothing scales with reduced motion
/// (`MediaQuery.disableAnimations`) or with [enabled] off, for dense
/// controls pressed many times in a row.
/// {@endtemplate}
class AppPressScale extends StatefulWidget {
  /// {@macro app_press_scale}
  const new({required this.builder, this.enabled = true, super.key});

  /// How small a pressed control is drawn.
  static const double pressedScale = 0.96;

  /// The widest control, in logical pixels, that scales.
  static const double maxWidth = 200;

  /// Builds the control, wired to the given states controller.
  final Widget Function(BuildContext context, WidgetStatesController states)
  builder;

  /// Whether the control scales when pressed.
  final bool enabled;

  @override
  State<AppPressScale> createState() => _AppPressScaleState();
}

class _AppPressScaleState extends State<AppPressScale>
    with SingleTickerProviderStateMixin {
  final _states = WidgetStatesController();
  late final _controller = AnimationController(vsync: this);
  late final Animation<double> _scale =
      Tween<double>(begin: 1, end: AppPressScale.pressedScale).animate(
        CurvedAnimation(
          parent: _controller,
          curve: AppMotion.press.curve,
          reverseCurve: AppMotion.press.curve.flipped,
        ),
      );

  @override
  void initState() {
    super.initState();
    _states.addListener(_statesChanged);
  }

  var _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    // Letting go glides back as quickly as the press went in.
    _controller.duration = AppMotion.press.duration;
    if (_still) _controller.value = 0;
  }

  void _statesChanged() {
    final pressed = _states.value.contains(WidgetState.pressed);
    if (pressed && widget.enabled && !_still) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _states
      ..removeListener(_statesChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scale,
    builder: (context, child) =>
        _PressScaleBox(scale: _scale.value, child: child),
    child: widget.builder(context, _states),
  );
}

class _PressScaleBox extends SingleChildRenderObjectWidget {
  const new({required this.scale, super.child});

  final double scale;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPressScale(scale);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPressScale renderObject,
  ) {
    renderObject.scale = scale;
  }
}

/// Scales its child about its centre when painting, unless it is wider than
/// [AppPressScale.maxWidth]. Layout and hit testing are left as they are: a
/// press a few points outside the shrunk control still lands on it.
class _RenderPressScale extends RenderProxyBox {
  new(this._scale);

  double _scale;

  double get scale => _scale;

  set scale(double value) {
    if (value == _scale) return;
    _scale = value;
    markNeedsPaint();
  }

  bool get _scales => scale != 1 && size.width <= AppPressScale.maxWidth;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_scales) {
      layer = null;
      return super.paint(context, offset);
    }
    final center = size.center(Offset.zero);
    final transform = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(_scale, _scale, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      super.paint,
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_scales) {
      final center = size.center(Offset.zero);
      transform
        ..translateByDouble(center.dx, center.dy, 0, 1)
        ..scaleByDouble(_scale, _scale, 1, 1)
        ..translateByDouble(-center.dx, -center.dy, 0, 1);
    }
    super.applyPaintTransform(child, transform);
  }
}
