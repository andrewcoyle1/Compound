import 'dart:async';
import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// {@template app_swipe_action}
/// One button behind a row, revealed by a swipe (a SwiftUI `swipeActions`
/// button).
/// {@endtemplate}
class AppSwipeAction {
  /// {@macro app_swipe_action}
  const new({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tint,
    this.isDestructive = false,
  });

  /// What the button does: shown when there is no [icon], and always the
  /// screen reader's name for it.
  final String label;

  /// Called when the button is tapped, swiped fully, or chosen from a screen
  /// reader's actions.
  final VoidCallback onPressed;

  /// Shown in place of [label].
  final IconData? icon;

  /// The button's fill. The danger colour when [isDestructive], else grey.
  final Color? tint;

  /// A destructive action (SwiftUI's `role: .destructive`): red.
  final bool isDestructive;
}

/// {@template app_swipe_actions}
/// A row with buttons behind it, as SwiftUI's `swipeActions`: swiping
/// towards the end reveals [leading], towards the start [trailing], each
/// side's first button at its outer edge. Built on `flutter_slidable`.
///
/// - Tapping a button runs it and closes the row; tapping the row while it
///   is open only closes it. Scrolling the list closes it too.
/// - Swiping on past most of the row's width runs that side's first button
///   at once, when [leadingFullSwipe] or [trailingFullSwipe] allows (as
///   `allowsFullSwipe`, both on by default). A haptic marks the point where
///   letting go will run it.
/// - Every button is also one of the row's screen-reader actions, as iOS
///   lists swipe actions, so nobody needs to swipe.
/// {@endtemplate}
class AppSwipeActions extends StatefulWidget {
  /// {@macro app_swipe_actions}
  const new({
    required this.child,
    this.leading = const [],
    this.trailing = const [],
    this.leadingFullSwipe = true,
    this.trailingFullSwipe = true,
    super.key,
  });

  /// The row.
  final Widget child;

  /// Buttons revealed by swiping towards the end (right, in English).
  final List<AppSwipeAction> leading;

  /// Buttons revealed by swiping towards the start (left, in English).
  final List<AppSwipeAction> trailing;

  /// Whether a full swipe runs the first [leading] button.
  final bool leadingFullSwipe;

  /// Whether a full swipe runs the first [trailing] button.
  final bool trailingFullSwipe;

  /// Each button's width, before a swipe past them all stretches them.
  static const buttonWidth = 74.0;

  /// The share of the row's width past which a full swipe runs.
  static const fullSwipeFraction = 0.6;

  @override
  State<AppSwipeActions> createState() => _AppSwipeActionsState();
}

class _AppSwipeActionsState extends State<AppSwipeActions>
    with SingleTickerProviderStateMixin {
  late final _Controller _controller;
  double _width = 0;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    // Added before the slidable's own listeners, so a full swipe has run
    // and the row is closing by the time they see the release.
    _controller = _Controller(this)
      ..animation.addListener(_onMoved)
      ..endGesture.addListener(_onReleased);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _startOpen => _controller.actionPaneType.value == .start;

  double _extent(List<AppSwipeAction> actions) =>
      math.min(1, actions.length * AppSwipeActions.buttonWidth / _width);

  /// Whether letting go now runs the open side's first button.
  bool get _pastFullSwipe {
    if (_controller.actionPaneType.value == .none) return false;
    final actions = _startOpen ? widget.leading : widget.trailing;
    final allowed = _startOpen
        ? widget.leadingFullSwipe
        : widget.trailingFullSwipe;
    final ratio = _controller.ratio.abs();
    return allowed &&
        ratio >= AppSwipeActions.fullSwipeFraction &&
        ratio > _extent(actions);
  }

  void _onMoved() {
    if (_controller.closing) return;
    final armed = _pastFullSwipe;
    if (armed != _armed) {
      _armed = armed;
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  void _onReleased() {
    if (!_armed) return;
    _armed = false;
    _run((_startOpen ? widget.leading : widget.trailing).first);
  }

  void _run(AppSwipeAction action) {
    unawaited(_controller.close());
    action.onPressed();
  }

  ActionPane? _pane(List<AppSwipeAction> actions, {required bool fullSwipe}) {
    if (actions.isEmpty) return null;
    final motion = _StretchMotion(width: _width, fullSwipe: fullSwipe);
    return ActionPane(
      extentRatio: _extent(actions),
      motion: motion,
      // Lets the row go past its buttons. The slidable would remove the row
      // once dismissed; [_onReleased] runs the button instead, so this
      // vetoes every dismissal and closes, and onDismissed never runs.
      dismissible: fullSwipe
          ? DismissiblePane(
              dismissThreshold: AppSwipeActions.fullSwipeFraction,
              confirmDismiss: () async => false,
              closeOnCancel: true,
              onDismissed: _controller.close,
              motion: motion,
            )
          : null,
      children: [
        for (final action in actions)
          _Button(action: action, onPressed: () => _run(action)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _controller.duration = AppMotion.quick.durationOf(context);
    return Semantics(
      customSemanticsActions: {
        for (final action in [...widget.leading, ...widget.trailing])
          CustomSemanticsAction(label: action.label): action.onPressed,
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _width = constraints.maxWidth;
          return Slidable(
            // DismissiblePane asserts its Slidable has a key.
            key: const Key('AppSwipeActions.slidable'),
            controller: _controller,
            startActionPane: _pane(
              widget.leading,
              fullSwipe: widget.leadingFullSwipe,
            ),
            endActionPane: _pane(
              widget.trailing,
              fullSwipe: widget.trailingFullSwipe,
            ),
            // The slidable loosens its child's width, and moves it by a share
            // of it: full width keeps the row in step with the buttons.
            child: SizedBox(
              width: _width,
              child: ValueListenableBuilder(
                valueListenable: _controller.direction,
                builder: (context, direction, child) => direction == 0
                    ? child!
                    : Stack(
                        fit: StackFit.passthrough,
                        children: [
                          child!,
                          Positioned.fill(
                            // Open, a tap on the row only closes it.
                            child: GestureDetector(
                              key: const Key('AppSwipeActions.close'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => unawaited(_controller.close()),
                              excludeFromSemantics: true,
                            ),
                          ),
                        ],
                      ),
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The slidable's controller, moving at [AppMotion.quick] (none under
/// reduced motion) and never past the middle to a side without buttons.
class _Controller extends SlidableController {
  new(super.vsync);

  Duration duration = AppMotion.quick.duration;

  // The slidable may open a pane from the pane's initState (a release that
  // came before its first frame), and a zero-length animation would then
  // notify mid-build. A microsecond still lands on the next frame.
  Duration get _moveDuration =>
      duration == Duration.zero ? const Duration(microseconds: 1) : duration;

  @override
  set ratio(double value) {
    final blocked =
        (value > 0 && !enablePositiveActionPane) ||
        (value < 0 && !enableNegativeActionPane);
    super.ratio = blocked ? 0 : value;
  }

  @override
  Future<void> openTo(
    double ratio, {
    Duration duration = Duration.zero,
    Curve curve = Curves.linear,
  }) => super.openTo(
    ratio,
    duration: _moveDuration,
    curve: AppMotion.quick.curve,
  );

  @override
  Future<void> close({
    Duration duration = Duration.zero,
    Curve curve = Curves.linear,
  }) => super.close(duration: _moveDuration, curve: AppMotion.quick.curve);
}

/// The open side's buttons, filling the gap the row has left: stretched past
/// their own widths, and all the first one's once a full swipe would run.
class const _StretchMotion({
  required final double width,
  required final bool fullSwipe,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pane = ActionPane.of(context)!;
    final controller = Slidable.of(context)!;
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: controller.animation,
          builder: (context, _) {
            final gap = math.min(
              controller.ratio.abs() * width,
              constraints.maxWidth,
            );
            final armed =
                fullSwipe &&
                gap >= width * AppSwipeActions.fullSwipeFraction &&
                gap > width * pane.extentRatio;
            final count = pane.children.length;
            final buttons = [
              for (final (index, button) in pane.children.indexed)
                SizedBox(
                  width: armed ? (index == 0 ? gap : 0) : gap / count,
                  child: button,
                ),
            ];
            return Align(
              alignment: pane.fromStart
                  ? AlignmentDirectional.centerStart
                  : AlignmentDirectional.centerEnd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                // The first button sits at the outer edge on either side.
                children: pane.fromStart ? buttons : buttons.reversed.toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const new({required this.action, required this.onPressed});

  final AppSwipeAction action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fill =
        action.tint ??
        (action.isDestructive
            ? context.appColors.danger
            : Theme.of(context).colorScheme.onSurfaceVariant);
    final ink = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
    final icon = action.icon;
    return Material(
      color: fill,
      child: InkWell(
        onTap: onPressed,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: icon != null
                  ? Icon(icon, color: ink)
                  : Text(
                      action.label,
                      style: AppTextStyles.label.copyWith(color: ink),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
