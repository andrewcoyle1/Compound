import 'dart:async';

import 'package:app_ui/app_ui.dart';

/// {@template app_busy_swap}
/// A control's content while its action may be under way: [idle] (the
/// label or icon) until [busy] has lasted [showAfter], then [spinner] in its
/// place, cross-faded over [AppMotion.quick].
///
/// A quick answer never flashes a spinner, and a slow one never flickers:
/// once shown, the spinner stays at least [holdFor]. [builder] gets the
/// content and whether the control is busy, which stays true from the first
/// frame of [busy] until the spinner has gone, so the control can disable
/// itself against a second press. [idle] and [spinner] share one spot, so the
/// control never changes size.
/// {@endtemplate}
class AppBusySwap extends StatefulWidget {
  /// {@macro app_busy_swap}
  const new({
    required this.busy,
    required this.idle,
    required this.spinner,
    required this.builder,
    super.key,
  });

  /// How long [busy] lasts before the spinner shows.
  static const showAfter = Duration(milliseconds: 300);

  /// The least time a spinner stays once shown.
  static const holdFor = Duration(milliseconds: 500);

  /// Whether the action is under way.
  final bool busy;

  /// The content while idle.
  final Widget idle;

  /// The content once the action has taken a while: an [AppSpinner].
  final Widget spinner;

  /// Builds the control around `content`; `busy` is whether it should be
  /// disabled.
  final Widget Function(
    BuildContext context,
    Widget content, {
    required bool busy,
  })
  builder;

  @override
  State<AppBusySwap> createState() => _AppBusySwapState();
}

class _AppBusySwapState extends State<AppBusySwap> {
  Timer? _show;
  Timer? _hold;

  /// Whether the spinner is shown.
  var _spinning = false;

  /// Whether the spinner has been up for [AppBusySwap.holdFor].
  var _held = false;

  /// Whether the spinner is still in the tree, fading out.
  var _leaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.busy) _wait();
  }

  @override
  void didUpdateWidget(AppBusySwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy == oldWidget.busy) return;
    if (widget.busy) {
      if (!_spinning) _wait();
    } else {
      _show?.cancel();
      if (_spinning && _held) _stop();
    }
  }

  void _wait() {
    _show?.cancel();
    _show = Timer(AppBusySwap.showAfter, () {
      setState(() {
        _spinning = true;
        _held = false;
      });
      _hold = Timer(AppBusySwap.holdFor, () {
        _held = true;
        if (!widget.busy) setState(_stop);
      });
    });
  }

  void _stop() {
    _spinning = false;
    _leaving = true;
  }

  @override
  void dispose() {
    _show?.cancel();
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.quick.durationOf(context);
    final curve = AppMotion.quick.curve;
    Widget fade({
      required bool shown,
      required Widget child,
      VoidCallback? onEnd,
    }) => AnimatedOpacity(
      opacity: shown ? 1 : 0,
      duration: duration,
      curve: curve,
      onEnd: onEnd,
      child: AnimatedScale(
        scale: shown ? 1 : 0.9,
        duration: duration,
        curve: curve,
        child: child,
      ),
    );
    final content = Stack(
      alignment: Alignment.center,
      children: [
        fade(shown: !_spinning, child: widget.idle),
        // In place, unseen and still, from the first frame of busy, so it
        // can fade in when the wait is over.
        if (widget.busy || _spinning || _leaving)
          fade(
            shown: _spinning,
            // A fade with no duration ends while building, so the spinner
            // leaves the tree on the next frame.
            onEnd: () => WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_spinning) setState(() => _leaving = false);
            }),
            child: TickerMode(
              enabled: _spinning || _leaving,
              child: widget.spinner,
            ),
          ),
      ],
    );
    return widget.builder(context, content, busy: widget.busy || _spinning);
  }
}
