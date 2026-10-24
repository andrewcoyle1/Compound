import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:showcaseview/showcaseview.dart';

/// {@template app_tip_callout}
/// A tip's card (TipKit's popover tip): a short title, a sentence or two on
/// how to use the feature, and [dismissLabel] ("Got It") to close it. Drawn
/// as the snack bar is: the dialog's surface, its hairline and a soft
/// shadow.
///
/// Given its [target], a notch on the edge facing it points at the
/// target's middle: on the top edge when the callout opens below, on the
/// bottom edge when it opens above.
///
/// A screen reader reads the title as the heading of what has appeared,
/// then the message, and can close it with Got It or the escape gesture;
/// what is beneath it is hidden from the reader while it shows.
/// {@endtemplate}
class AppTipCallout extends StatelessWidget {
  /// {@macro app_tip_callout}
  const new({
    required this.title,
    required this.message,
    required this.dismissLabel,
    required this.onDismiss,
    this.target,
    super.key,
  });

  /// What the feature is, in a few words.
  final String title;

  /// How to use it, in a sentence or two.
  final String message;

  /// Where the target is on screen, read as the callout paints; none
  /// draws no notch.
  final ValueGetter<Rect?>? target;

  /// The close button's label, localized ("Got It").
  final String dismissLabel;

  /// Closes the tip.
  final VoidCallback onDismiss;

  /// The widest a callout grows, on iPad, so its lines stay readable.
  static const maxWidth = 400.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BlockSemantics(
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        onDismiss: onDismiss,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: _Notch(
            target: target,
            fill: scheme.surfaceContainerHigh,
            stroke: scheme.outlineVariant,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                border: Border.all(color: scheme.outlineVariant, width: 0.5),
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.l),
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.12),
                    blurRadius: AppSpacing.l,
                    offset: const Offset(0, AppSpacing.xs),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.l,
                  AppSpacing.m,
                  AppSpacing.s,
                  AppSpacing.xs,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.xxs,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.s,
                      ),
                      child: Semantics(
                        header: true,
                        namesRoute: true,
                        child: Text(
                          title,
                          style: AppTextStyles.rowTitle.semibold.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.s,
                      ),
                      child: Text(
                        message,
                        style: AppTextStyles.rowDetail.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      // showcaseview hosts the card on Flutter's own
                      // Material, which the app's buttons do not recognise.
                      child: Material(
                        type: MaterialType.transparency,
                        child: AppTextButton(
                          label: dismissLabel,
                          onPressed: onDismiss,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The callout's notch: a small triangle in the callout's own fill, with
/// its hairline, on the edge facing the target and over its middle (kept
/// clear of the rounded corners).
class _Notch extends SingleChildRenderObjectWidget {
  const new({
    required this.target,
    required this.fill,
    required this.stroke,
    required super.child,
  });

  final ValueGetter<Rect?>? target;
  final Color fill;
  final Color stroke;

  @override
  _RenderNotch createRenderObject(BuildContext context) =>
      _RenderNotch(target: target, fill: fill, stroke: stroke);

  @override
  void updateRenderObject(BuildContext context, _RenderNotch renderObject) =>
      renderObject
        ..target = target
        ..fill = fill
        ..stroke = stroke
        ..markNeedsPaint();
}

class _RenderNotch extends RenderProxyBox {
  new({required this.target, required this.fill, required this.stroke});

  ValueGetter<Rect?>? target;
  Color fill;
  Color stroke;

  /// Half the notch's width, and its height.
  static const double half = AppSpacing.s;
  static const double height = AppSpacing.s;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final rect = target?.call();
    if (rect == null) return;
    final me = localToGlobal(Offset.zero) & size;
    // Below the target, the notch is on the top edge and points up.
    final below = me.center.dy > rect.center.dy;
    final x = (rect.center.dx - me.left).clamp(
      AppRadius.l + half,
      size.width - AppRadius.l - half,
    );
    final edge = below ? 0.0 : size.height;
    final tip = below ? -height : size.height + height;
    // The base sits just inside the card, over its hairline.
    final base = edge + (below ? 1 : -1);
    context.canvas
      ..drawPath(
        Path()
          ..moveTo(offset.dx + x - half, offset.dy + base)
          ..lineTo(offset.dx + x, offset.dy + tip)
          ..lineTo(offset.dx + x + half, offset.dy + base)
          ..close(),
        Paint()..color = fill,
      )
      ..drawPath(
        Path()
          ..moveTo(offset.dx + x - half, offset.dy + edge)
          ..lineTo(offset.dx + x, offset.dy + tip)
          ..lineTo(offset.dx + x + half, offset.dy + edge),
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
  }
}

/// {@template app_tip_scope}
/// Shows one of a screen's [AppTip]s, at most once per visit: the first in
/// [tips] that [isSeen] says is new and whose target is on screen, a moment
/// ([settle]) after the screen comes into view or a scroll ends. Built on
/// showcaseview's spotlight.
///
/// - The tip dims the screen, except its target, and puts an
///   [AppTipCallout] beside it. Tapping anywhere, or Got It, closes it.
/// - Nothing moves: the callout neither bounces nor scales in, so reduced
///   motion needs nothing more.
/// - It shows only while this screen is the current route of a visible
///   branch (`TickerMode`), and closes if that stops being true.
///
/// [onShown] is the moment to remember a tip as seen; [onDismissed] follows
/// when it closes, however it closed.
/// {@endtemplate}
class AppTipScope extends StatefulWidget {
  /// {@macro app_tip_scope}
  const new({
    required this.tips,
    required this.isSeen,
    required this.onShown,
    required this.onDismissed,
    required this.dismissLabel,
    required this.child,
    super.key,
  });

  /// The screen's tip ids, in the order they are offered.
  final List<String> tips;

  /// Whether a tip has been shown before, so is never shown again.
  final bool Function(String id) isSeen;

  /// A tip has just shown.
  final ValueChanged<String> onShown;

  /// A tip has just closed.
  final ValueChanged<String> onDismissed;

  /// The callout's close button label, localized ("Got It").
  final String dismissLabel;

  /// The screen.
  final Widget child;

  /// How long the screen is left in view before a tip shows.
  static const settle = Duration(seconds: 1);

  @override
  State<AppTipScope> createState() => _AppTipScopeState();
}

class _AppTipScopeState extends State<AppTipScope> {
  late final String _name = 'AppTipScope#${identityHashCode(this)}';
  late final ShowcaseView _view;
  final _tips = <_AppTipState>[];
  Timer? _timer;

  /// Whether this visit has shown its tip.
  bool _done = false;

  /// The tip on screen.
  _AppTipState? _showing;

  @override
  void initState() {
    super.initState();
    _view = ShowcaseView.register(
      scope: _name,
      disableMovingAnimation: true,
      disableScaleAnimation: true,
      onFinish: _closed,
      onDismiss: (_) => _closed(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inView) {
      dismiss();
    } else {
      _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _closed();
    _view.unregister();
    super.dispose();
  }

  bool get _inView =>
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  void _add(_AppTipState tip) {
    _tips.add(tip);
    _schedule();
  }

  void _remove(_AppTipState tip) {
    _tips.remove(tip);
    if (tip == _showing) dismiss();
  }

  void _schedule() {
    if (_done) return;
    _timer?.cancel();
    _timer = Timer(AppTipScope.settle, _show);
  }

  void _show() {
    if (!mounted || _done || !_inView) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final area = MediaQuery.paddingOf(context)
        .deflateRect(box.localToGlobal(Offset.zero) & box.size)
        .inflate(1);
    for (final id in widget.tips) {
      if (widget.isSeen(id)) continue;
      // The topmost wholly on screen, where several rows carry one tip.
      _AppTipState? pick;
      for (final tip in _tips) {
        if (tip.widget.id != id) continue;
        final rect = tip.rect;
        if (rect == null || !_contains(area, rect)) continue;
        if (pick == null || rect.top < pick.rect!.top) pick = tip;
      }
      if (pick == null) continue;
      _done = true;
      _showing = pick;
      _view.startShowCase([pick.key]);
      widget.onShown(id);
      return;
    }
  }

  static bool _contains(Rect outer, Rect inner) =>
      inner.left >= outer.left &&
      inner.top >= outer.top &&
      inner.right <= outer.right &&
      inner.bottom <= outer.bottom;

  /// Closes the tip showing, if any.
  void dismiss() {
    if (_showing != null) _view.dismiss();
  }

  void _closed() {
    final tip = _showing;
    if (tip == null) return;
    _showing = null;
    widget.onDismissed(tip.widget.id);
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollEndNotification>(
        onNotification: (_) {
          _schedule();
          return false;
        },
        child: widget.child,
      );
}

/// {@template app_tip}
/// Marks [child] as the target of tip [id], which the nearest
/// [AppTipScope] may show once: [title] and [message] in an
/// [AppTipCallout] beside it. Without a scope above it, it is only
/// [child].
///
/// Tips are for what is easy to miss, such as a gesture with nothing on
/// screen to show it; not a tour of what is plain to see. Several widgets
/// may carry one id, as every row of a list can; the topmost on screen is
/// the one shown.
/// {@endtemplate}
class AppTip extends StatefulWidget {
  /// {@macro app_tip}
  const new({
    required this.id,
    required this.title,
    required this.message,
    required this.child,
    super.key,
  });

  /// The tip, as its [AppTipScope] lists it.
  final String id;

  /// What the feature is, in a few words.
  final String title;

  /// How to use it, in a sentence or two.
  final String message;

  /// The target.
  final Widget child;

  @override
  State<AppTip> createState() => _AppTipState();
}

class _AppTipState extends State<AppTip> {
  final GlobalKey key = GlobalKey();
  _AppTipScopeState? _scope;

  /// Where the target is on screen, once laid out.
  Rect? get rect {
    // The overlay may paint once more after this has left the tree.
    if (!_active) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  void initState() {
    super.initState();
    _scope = context.findAncestorStateOfType<_AppTipScopeState>()?.._add(this);
  }

  bool _active = true;

  @override
  void deactivate() {
    _active = false;
    super.deactivate();
  }

  @override
  void dispose() {
    _scope?._remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Back in the tree, as after a move with a global key.
    _active = true;
    final scope = _scope;
    if (scope == null) return widget.child;
    return Showcase.withWidget(
      key: key,
      scope: scope._name,
      overlayColor: Theme.of(context).colorScheme.scrim,
      overlayOpacity: 0.4,
      targetPadding: const EdgeInsets.all(AppSpacing.xs),
      targetBorderRadius: const BorderRadius.all(Radius.circular(AppRadius.m)),
      toolTipMargin: AppSpacing.l,
      // Room for the callout's notch.
      targetTooltipGap: AppSpacing.m,
      container: AppTipCallout(
        title: widget.title,
        message: widget.message,
        dismissLabel: scope.widget.dismissLabel,
        onDismiss: scope.dismiss,
        target: () => rect,
      ),
      child: widget.child,
    );
  }
}
