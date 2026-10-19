import 'package:app_ui/app_ui.dart';

/// {@template app_text_button}
/// A low-emphasis action drawn as text: See All, Not now, Skip. The label is
/// in the accent, or `danger` when [isDestructive]. Its tap target is at
/// least 44 pt.
///
/// For a quiet alternative under a screen's call to action, use
/// [AppCtaVariant.plain] instead.
/// {@endtemplate}
class AppTextButton extends StatelessWidget {
  /// {@macro app_text_button}
  const new({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
    super.key,
  });

  /// The button's text, localized.
  final String label;

  /// Called when tapped. `null` disables the button.
  final VoidCallback? onPressed;

  /// Whether the action deletes or removes something.
  final bool isDestructive;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: isDestructive
          ? context.appColors.danger
          : Theme.of(context).colorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
    ),
    child: Text(label),
  );
}
