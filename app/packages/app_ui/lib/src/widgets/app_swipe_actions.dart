import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

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
/// side's first button at its outer edge.
///
/// - Tapping a button runs it and closes the row; tapping the row while it
///   is open only closes it.
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
  // How far the row has moved towards the end (leading side showing) when
  // positive, towards the start when negative: logical, whatever the text
  // direction.
  late final _offset = AnimationController.unbounded(vsync: this);
  double _width = 0;
  bool _armed = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  bool get _isLtr => Directionality.of(context) == TextDirection.ltr;

  List<AppSwipeAction> _side(double offset) =>
      offset > 0 ? widget.leading : widget.trailing;

  bool _fullSwipe(double offset) =>
      offset > 0 ? widget.leadingFullSwipe : widget.trailingFullSwipe;

  double _revealed(double offset) =>
      _side(offset).length * AppSwipeActions.buttonWidth;

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta! * (_isLtr ? 1 : -1);
    var next = _offset.value + delta;
    if (next > 0 && widget.leading.isEmpty) next = 0;
    if (next < 0 && widget.trailing.isEmpty) next = 0;
    final limit = _fullSwipe(next) ? _width : _revealed(next);
    _offset.value = next.clamp(-limit, limit);
    final armed =
        _fullSwipe(next) &&
        next.abs() > _width * AppSwipeActions.fullSwipeFraction;
    if (armed != _armed) {
      _armed = armed;
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final offset = _offset.value;
    if (_armed) {
      _armed = false;
      _run(_side(offset).first);
      return;
    }
    final velocity = details.primaryVelocity! * (_isLtr ? 1 : -1);
    final opening = velocity.abs() > 300
        ? velocity.sign == offset.sign
        : offset.abs() > _revealed(offset) / 2;
    _settle(opening ? _revealed(offset) * offset.sign : 0);
  }

  void _settle(double target) => _offset.animateTo(
    target,
    duration: AppMotion.quick.durationOf(context),
    curve: AppMotion.quick.curve,
  );

  void _run(AppSwipeAction action) {
    _settle(0);
    action.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        for (final action in [...widget.leading, ...widget.trailing])
          CustomSemanticsAction(label: action.label): action.onPressed,
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _width = constraints.maxWidth;
          return GestureDetector(
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _offset,
                builder: (context, child) {
                  final offset = _offset.value;
                  return Stack(
                    // The row keeps the width it would have had alone.
                    fit: StackFit.passthrough,
                    children: [
                      if (offset != 0)
                        Positioned.fill(child: _buttons(context, offset)),
                      Transform.translate(
                        offset: Offset(offset * (_isLtr ? 1 : -1), 0),
                        child: offset == 0
                            ? child
                            : Stack(
                                fit: StackFit.passthrough,
                                children: [
                                  ?child,
                                  Positioned.fill(
                                    // Open, a tap on the row only closes it.
                                    child: GestureDetector(
                                      key: const Key('AppSwipeActions.close'),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _settle(0),
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  );
                },
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }

  /// The side's buttons, filling the gap the row has left: stretched past
  /// their own widths, and all the first one's once a full swipe would run.
  Widget _buttons(BuildContext context, double offset) {
    final actions = _side(offset);
    final gap = offset.abs();
    final armed =
        _fullSwipe(offset) && gap > _width * AppSwipeActions.fullSwipeFraction;
    final buttons = [
      for (final (index, action) in actions.indexed)
        SizedBox(
          width: armed ? (index == 0 ? gap : 0) : gap / actions.length,
          child: _Button(action: action, onPressed: () => _run(action)),
        ),
    ];
    return ExcludeSemantics(
      child: Align(
        alignment: offset > 0
            ? AlignmentDirectional.centerStart
            : AlignmentDirectional.centerEnd,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // The first button sits at the outer edge on either side.
          children: offset > 0 ? buttons : buttons.reversed.toList(),
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
