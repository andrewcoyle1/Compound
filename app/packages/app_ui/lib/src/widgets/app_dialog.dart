import 'package:app_ui/app_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoAlertDialog, CupertinoDialogAction, CupertinoDialogRoute;
import 'package:flutter/physics.dart' show FrictionSimulation;

/// What an [AppDialogAction] does, which sets how it is drawn.
enum AppDialogRole {
  /// An ordinary choice, in the accent.
  standard,

  /// The action the dialog suggests, in bold.
  preferred,

  /// Backs out and changes nothing. Bold on iOS when no action is
  /// [preferred], as iOS draws Cancel.
  cancel,

  /// Deletes or discards something, in `danger`.
  destructive,
}

/// {@template app_dialog_action}
/// A button in an [AppDialog]. Tapping it closes the dialog with [value],
/// unless [onPressed] is given: then [onPressed] runs instead, and closes
/// the dialog itself (for a text field whose value is read on submit).
/// {@endtemplate}
class AppDialogAction<T> {
  /// {@macro app_dialog_action}
  const new({
    required this.label,
    this.value,
    this.role = AppDialogRole.standard,
    this.onPressed,
  });

  /// The button's text, localized.
  final String label;

  /// What the dialog returns when this is tapped.
  final T? value;

  /// How the action is drawn.
  final AppDialogRole role;

  /// Runs in place of closing with [value].
  final VoidCallback? onPressed;
}

/// {@template app_dialog}
/// An alert or confirmation: a title, an optional message, optional extra
/// [content] such as a text field, and a row of [actions].
///
/// One API, drawn the platform's way: on iOS an iOS alert, whose actions are
/// in the accent, [AppDialogRole.destructive] in `danger` and the preferred
/// one bold; elsewhere a Material dialog on `surface` with the same colours.
/// More than two actions stack, with Cancel moved last. Open it with
/// [showAppDialog], or [AppDialog.confirmDestructive] for an irreversible
/// action.
///
/// For a choice between options, give one action per option and a Cancel.
/// {@endtemplate}
class AppDialog<T> extends StatelessWidget {
  /// {@macro app_dialog}
  const new({
    required this.title,
    required this.actions,
    this.message,
    this.content,
    super.key,
  });

  /// The question or statement, localized.
  final String title;

  /// More detail, localized.
  final String? message;

  /// Anything else the dialog needs, under [message], such as a text field.
  final Widget? content;

  /// The buttons, in reading order; Cancel usually first.
  final List<AppDialogAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final danger = context.appColors.danger;
    final hasPreferred = actions.any(
      (action) => action.role == AppDialogRole.preferred,
    );
    final message = this.message;
    final content = this.content;
    // Material widgets in [content], such as a TextField, need a Material
    // ancestor, which the iOS alert lacks.
    final extra = content == null
        ? null
        : Material(type: MaterialType.transparency, child: content);
    VoidCallback onPressed(AppDialogAction<T> action) =>
        action.onPressed ?? () => Navigator.of(context).pop(action.value);

    // More than two actions stack, and then Cancel goes to the bottom, as
    // both platforms place it.
    final ordered = actions.length > 2
        ? [
            ...actions.where((a) => a.role != AppDialogRole.cancel),
            ...actions.where((a) => a.role == AppDialogRole.cancel),
          ]
        : actions;

    if (theme.platform case TargetPlatform.iOS || TargetPlatform.macOS) {
      return CupertinoAlertDialog(
        title: Text(title),
        content: message == null && extra == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpacing.m,
                children: [?_text(message), ?extra],
              ),
        actions: [
          for (final action in ordered)
            CupertinoDialogAction(
              onPressed: onPressed(action),
              isDefaultAction: _isBold(action, hasPreferred: hasPreferred),
              isDestructiveAction: action.role == AppDialogRole.destructive,
              textStyle: TextStyle(
                color: action.role == AppDialogRole.destructive
                    ? danger
                    : context.appColors.accentInk,
              ),
              child: Text(action.label),
            ),
        ],
      );
    }

    return AlertDialog(
      title: Text(title),
      // From the theme's text theme, which carries the platform's font.
      titleTextStyle: text.titleMedium!.copyWith(color: scheme.onSurface),
      contentTextStyle: text.bodyMedium!
          .merge(AppTextStyles.rowDetail)
          .copyWith(color: scheme.onSurfaceVariant),
      content: message == null && extra == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.l,
              children: [?_text(message), ?extra],
            ),
      scrollable: true,
      actions: [
        for (final action in ordered)
          TextButton(
            onPressed: onPressed(action),
            style: TextButton.styleFrom(
              foregroundColor: action.role == AppDialogRole.destructive
                  ? danger
                  : context.appColors.accentInk,
              textStyle: text.bodyMedium!.copyWith(
                fontWeight: action.role == AppDialogRole.preferred
                    ? FontWeight.w600
                    : null,
              ),
            ),
            child: Text(action.label, textAlign: TextAlign.end),
          ),
      ],
    );
  }

  /// Asks before an irreversible action: [confirmLabel] in `danger` beside
  /// [cancelLabel] (Material's localized "Cancel" by default). True only once
  /// confirmed.
  static Future<bool> confirmDestructive(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String? message,
    String? cancelLabel,
  }) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: title,
      message: message,
      actions: [
        AppDialogAction(
          label:
              cancelLabel ??
              MaterialLocalizations.of(context).cancelButtonLabel,
          value: false,
          role: AppDialogRole.cancel,
        ),
        AppDialogAction(
          label: confirmLabel,
          value: true,
          role: AppDialogRole.destructive,
        ),
      ],
    );
    return confirmed ?? false;
  }

  static Widget? _text(String? message) =>
      message == null ? null : Text(message);

  static bool _isBold(
    AppDialogAction<Object?> action, {
    required bool hasPreferred,
  }) =>
      action.role == AppDialogRole.preferred ||
      (action.role == AppDialogRole.cancel && !hasPreferred);
}

/// Shows an [AppDialog] the platform's way (an iOS alert, which only an
/// action closes, or a Material dialog, which a tap outside closes too) and
/// returns the chosen action's value, or null when dismissed.
///
/// With reduced motion (`MediaQuery.disableAnimations`) it appears and goes
/// without a transition, as sheets do.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  required List<AppDialogAction<T>> actions,
  String? message,
  Widget? content,
}) {
  Widget builder(BuildContext _) => AppDialog<T>(
    title: title,
    message: message,
    content: content,
    actions: actions,
  );
  final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  if (!still) return showAdaptiveDialog<T>(context: context, builder: builder);
  return switch (Theme.of(context).platform) {
    // showAdaptiveDialog leaves the iOS alert's transition as it is, so the
    // route is pushed here as showCupertinoDialog would, with none.
    TargetPlatform.iOS ||
    TargetPlatform.macOS => Navigator.of(context, rootNavigator: true).push<T>(
      _StillCupertinoDialogRoute<T>(builder: builder, context: context),
    ),
    _ => showDialog<T>(
      context: context,
      builder: builder,
      animationStyle: AnimationStyle.noAnimation,
    ),
  };
}

/// An iOS alert that appears and goes at once: the stock route springs in
/// whatever its duration, so this one starts where the spring would stop.
class _StillCupertinoDialogRoute<T> extends CupertinoDialogRoute<T> {
  new({required super.builder, required super.context})
    : super(transitionDuration: Duration.zero);

  // Standing still at the end: no velocity, so it is done at once.
  @override
  Simulation createSimulation({required bool forward}) =>
      FrictionSimulation(0.5, forward ? 1 : 0, 0);
}
