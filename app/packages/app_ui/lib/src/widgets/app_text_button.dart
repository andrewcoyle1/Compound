import 'package:app_ui/app_ui.dart';

/// {@template app_text_button}
/// A low-emphasis action drawn as text: See All, Not now, Skip. The label is
/// in the accent, or `danger` when [isDestructive]. Its tap target is at
/// least 44 pt.
///
/// An [inline] one is a link inside content, such as "Edit Weights" under a
/// row's detail: it has no side padding, so it lines up with the text
/// above it, and is set in the row detail's size, semibold.
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
    this.inline = false,
    super.key,
  });

  /// The button's text, localized.
  final String label;

  /// Called when tapped. `null` disables the button.
  final VoidCallback? onPressed;

  /// Whether the action deletes or removes something.
  final bool isDestructive;

  /// Whether it is a link inside content, lined up with the text above.
  final bool inline;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: isDestructive
          ? context.appColors.danger
          : Theme.of(context).colorScheme.primary,
      padding: inline
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      minimumSize: inline ? const Size(0, AppControlSize.row) : null,
      alignment: inline ? AlignmentDirectional.centerStart : null,
      // Padding the target out to 48 would centre the text in it.
      tapTargetSize: inline ? MaterialTapTargetSize.shrinkWrap : null,
      textStyle: inline
          ? AppTextStyles.rowDetail.copyWith(fontWeight: FontWeight.w600)
          : null,
    ),
    child: Text(label),
  );
}
