import 'dart:async';
import 'dart:math' as math;

import 'package:another_flushbar/flushbar.dart' show Flushbar;
import 'package:app_ui/app_ui.dart';

/// The kind of an [AppSnackBar]: which icon it shows, and in which colour.
enum AppSnackBarStyle {
  /// A neutral note, such as "Set deleted": the info icon in secondary grey.
  info,

  /// Something saved or done: a check in `success`.
  success,

  /// Something failed: the error icon in `danger`.
  error,
}

/// {@template app_snack_bar_action}
/// The one button on an [AppSnackBar], such as Undo.
/// {@endtemplate}
class AppSnackBarAction {
  /// {@macro app_snack_bar_action}
  const new({required this.label, required this.onPressed});

  /// The button's text, localized.
  final String label;

  /// Called when tapped. The snack bar then goes.
  final VoidCallback onPressed;
}

/// Shows [message] in a snack bar at the bottom of the screen, above the
/// tab bar, a bottom call to action and the keyboard, in place of any
/// already showing.
///
/// It goes after [duration], 4 seconds by default; with an [action] and no
/// [duration] it stays until it is swiped away, its action is tapped or
/// another replaces it, as Material's does. Screen readers announce it.
///
/// The app must have an [AppSnackBarScope] above [context]. To show one
/// once [context] may be gone, such as after a save, take
/// `AppSnackBarScope.of(context)` first and call its `show` later.
void showAppSnackBar(
  BuildContext context,
  String message, {
  AppSnackBarAction? action,
  AppSnackBarStyle style = AppSnackBarStyle.info,
  Duration? duration,
}) =>
    AppSnackBarScope.of(context)
        .show(message, action: action, style: style, duration: duration);

/// {@template app_snack_bar}
/// A snack bar's card: [style]'s icon, the [message] and an optional
/// [action], on a raised surface with continuous corners. Drawn by
/// another_flushbar's `Flushbar`.
///
/// Screens show one with [showAppSnackBar] rather than building it.
/// {@endtemplate}
class AppSnackBar extends StatelessWidget {
  /// {@macro app_snack_bar}
  const new({
    required this.message,
    this.style = AppSnackBarStyle.info,
    this.action,
    super.key,
  });

  /// The message, localized.
  final String message;

  /// Its icon and the icon's colour.
  final AppSnackBarStyle style;

  /// A button at the trailing edge, such as Undo.
  final AppSnackBarAction? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final (icon, color) = switch (style) {
      AppSnackBarStyle.info => (AppSymbols.info, scheme.onSurfaceVariant),
      AppSnackBarStyle.success => (AppSymbols.success, colors.success),
      AppSnackBarStyle.error => (AppSymbols.error, colors.danger),
    };
    final text = AppTextStyles.rowTitle.copyWith(color: scheme.onSurface);
    final action = this.action;
    return Flushbar<void>(
      messageText: Text(message, style: text),
      icon: Icon(
        icon,
        color: color,
        size: MediaQuery.textScalerOf(context).scale(text.fontSize!),
      ),
      // A pulsing icon never settles, and draws the eye for no reason.
      shouldIconPulse: false,
      // Flushbar sits on Flutter's own Material, which the app's buttons
      // do not recognise, so the button brings the app's.
      mainButton: action == null
          ? null
          : Material(
              type: MaterialType.transparency,
              child: AppTextButton(
                label: action.label,
                onPressed: action.onPressed,
              ),
            ),
      // Flushbar takes 12 off the right for the button, which pads its
      // label already.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.m,
        AppSpacing.xl,
        AppSpacing.m,
      ),
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xl)),
      // Raised off the canvas and off a card alike: the dialog's surface,
      // its hairline and a soft shadow.
      backgroundColor: scheme.surfaceContainerHigh,
      borderColor: scheme.outlineVariant,
      borderWidth: 0.5,
      boxShadows: [
        BoxShadow(
          color: scheme.shadow.withValues(alpha: 0.12),
          blurRadius: AppSpacing.l,
          offset: const Offset(0, AppSpacing.xs),
        ),
      ],
      textDirection: Directionality.of(context),
    );
  }
}

/// {@template app_snack_bar_scope}
/// Where [showAppSnackBar] draws: above [child], which is the app's
/// navigator, so a snack bar outlives the screen that showed it, as
/// Material's `ScaffoldMessenger` does. Put one in `MaterialApp.builder`.
///
/// One snack bar shows at a time, centred in the readable width, clear of
/// the safe area, the keyboard and any [AppSnackBarClearance] along the
/// bottom edge that is on screen (the tab bar, a bottom call to action).
/// It slides up in [AppMotion.standard], or simply appears when the user
/// has asked for reduced motion, and swipes down to dismiss.
///
/// another_flushbar shows a `Flushbar` as a route, which would take the
/// back gesture and `pop()` from the screen beneath it, so only its card
/// ([AppSnackBar]) is used, hosted here.
/// {@endtemplate}
class AppSnackBarScope extends StatefulWidget {
  /// {@macro app_snack_bar_scope}
  const new({required this.child, super.key});

  /// The app, usually `MaterialApp.builder`'s child.
  final Widget child;

  /// The nearest scope above [context].
  static AppSnackBarScopeState of(BuildContext context) {
    final scope = context.findAncestorStateOfType<AppSnackBarScopeState>();
    if (scope == null) {
      throw FlutterError(
        'No AppSnackBarScope found above this context.\n'
        'Wrap the app in one in MaterialApp.builder.',
      );
    }
    return scope;
  }

  @override
  State<AppSnackBarScope> createState() => AppSnackBarScopeState();
}

/// The state of an [AppSnackBarScope], which shows its snack bars.
class AppSnackBarScopeState extends State<AppSnackBarScope> {
  /// How long a snack bar without an action stays: Material's default.
  static const defaultDuration = Duration(seconds: 4);

  final _bars = <_AppSnackBarClearanceState>{};
  _Toast? _toast;
  var _serial = 0;
  double _clearance = 0;

  /// Shows [message], replacing any snack bar showing; see
  /// [showAppSnackBar].
  void show(
    String message, {
    AppSnackBarAction? action,
    AppSnackBarStyle style = AppSnackBarStyle.info,
    Duration? duration,
  }) {
    if (!mounted) return;
    _clearance = _measure();
    setState(
      () => _toast = _Toast(
        id: ++_serial,
        message: message,
        action: action,
        style: style,
        duration: duration ?? (action == null ? defaultDuration : null),
      ),
    );
  }

  void _gone(_Toast toast) {
    if (mounted && _toast?.id == toast.id) setState(() => _toast = null);
  }

  /// A bar came, went, or came on or off screen: measure again once laid
  /// out. ponytail: a bar resizing under a showing snack bar (an accessory
  /// appearing) is measured only with the next one.
  void _barsChanged() {
    if (_toast == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final clearance = _measure();
      if (clearance != _clearance) setState(() => _clearance = clearance);
    });
  }

  /// How far up from the bottom edge the bars on screen reach.
  double _measure() {
    final scope = context.findRenderObject();
    if (scope is! RenderBox || !scope.hasSize) return 0;
    var clearance = 0.0;
    for (final bar in _bars) {
      final box = bar.context.findRenderObject();
      if (!bar.onStage || box is! RenderBox || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: scope).dy;
      // Only a bar along the bottom edge, not one shown in a list.
      if (top + box.size.height < scope.size.height - 1) continue;
      clearance = math.max(clearance, scope.size.height - top);
    }
    return clearance;
  }

  @override
  Widget build(BuildContext context) {
    final toast = _toast;
    // Always a Stack, so the app below keeps its state as snack bars come
    // and go.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (toast != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: _bottom(context) + AppSpacing.s,
            child: AppReadableWidth(
              child: SafeArea(
                top: false,
                bottom: false,
                minimum: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: _ToastHost(
                  key: ValueKey(toast.id),
                  toast: toast,
                  onGone: () => _gone(toast),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The highest of the bars, the keyboard and the home indicator.
  double _bottom(BuildContext context) => [
    _clearance,
    MediaQuery.viewInsetsOf(context).bottom,
    MediaQuery.viewPaddingOf(context).bottom,
  ].reduce(math.max);
}

/// {@template app_snack_bar_clearance}
/// Marks [child] as a bar along the bottom of the screen that snack bars
/// sit above while it is on screen. [AppTabBar] and [AppBottomCta] use it.
/// {@endtemplate}
class AppSnackBarClearance extends StatefulWidget {
  /// {@macro app_snack_bar_clearance}
  const new({required this.child, super.key});

  /// The bar.
  final Widget child;

  @override
  State<AppSnackBarClearance> createState() => _AppSnackBarClearanceState();
}

class _AppSnackBarClearanceState extends State<AppSnackBarClearance> {
  AppSnackBarScopeState? _scope;

  /// Whether the bar is on screen: not under another screen or in a tab
  /// that is not showing.
  bool onStage = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    onStage = TickerMode.valuesOf(context).enabled;
    _scope ??= context.findAncestorStateOfType<AppSnackBarScopeState>()
      ?.._bars.add(this);
    _scope?._barsChanged();
  }

  @override
  void dispose() {
    _scope
      ?.._bars.remove(this)
      .._barsChanged();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Toast {
  const new({
    required this.id,
    required this.message,
    required this.action,
    required this.style,
    required this.duration,
  });

  final int id;
  final String message;
  final AppSnackBarAction? action;
  final AppSnackBarStyle style;

  /// Null to stay until dismissed.
  final Duration? duration;
}

/// One snack bar's life: in, a wait, out; or swiped away.
class _ToastHost extends StatefulWidget {
  const new({required this.toast, required this.onGone, super.key});

  final _Toast toast;
  final VoidCallback onGone;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this)
    ..addStatusListener(_statusChanged);
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.standard.curve,
  );
  Timer? _timer;
  var _leaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = AppMotion.standard.durationOf(context);
    if (_controller.isDismissed && !_leaving) _controller.forward();
  }

  void _statusChanged(AnimationStatus status) {
    final duration = widget.toast.duration;
    if (status.isCompleted && duration != null) {
      _timer = Timer(duration, _dismiss);
    } else if (status.isDismissed && _leaving) {
      widget.onGone();
    }
  }

  void _dismiss() {
    if (_leaving) return;
    _leaving = true;
    _timer?.cancel();
    _controller.reverse();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toast = widget.toast;
    final action = toast.action;
    return Semantics(
      container: true,
      liveRegion: true,
      onDismiss: _dismiss,
      child: Dismissible(
        key: ValueKey(toast.id),
        direction: DismissDirection.down,
        movementDuration: AppMotion.quick.durationOf(context),
        resizeDuration: null,
        onDismissed: (_) {
          _timer?.cancel();
          widget.onGone();
        },
        child: FadeTransition(
          opacity: _curve,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(_curve),
            child: AppSnackBar(
              message: toast.message,
              style: toast.style,
              action: action == null
                  ? null
                  : AppSnackBarAction(
                      label: action.label,
                      onPressed: () {
                        action.onPressed();
                        _dismiss();
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
