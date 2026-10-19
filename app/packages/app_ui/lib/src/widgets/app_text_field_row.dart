import 'package:app_ui/app_ui.dart';

/// {@template app_text_field_row}
/// A text entry row in an [AppSection], as a Swift `Form`'s `TextField`:
/// the typed text in row type, and [label] as the placeholder while it is
/// empty. Screen readers hear [label] whether or not the row has text. It is
/// at least as tall as an [AppListRow] and grows with the text size.
///
/// For a number, use [AppNumberField].
/// {@endtemplate}
class AppTextFieldRow extends StatelessWidget {
  /// {@macro app_text_field_row}
  const new({
    required this.label,
    required this.onChanged,
    this.initialValue,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.sentences,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
    super.key,
  });

  /// What the field holds, localized: its placeholder and accessible name.
  final String label;

  /// Called on every edit with the text typed.
  final ValueChanged<String> onChanged;

  /// The text the field starts with.
  final String? initialValue;

  /// What autofill may offer, such as [AutofillHints.givenName].
  final Iterable<String>? autofillHints;

  /// How the keyboard capitalises, such as words for a name.
  final TextCapitalization textCapitalization;

  /// The keyboard's action button.
  final TextInputAction? textInputAction;

  /// Called when the keyboard's action button is pressed.
  final ValueChanged<String>? onSubmitted;

  /// Whether the field takes focus when it first appears.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppControlSize.listRow),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        // A row, so the field sits in the middle of a taller row.
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                label: label,
                child: TextFormField(
                  initialValue: initialValue,
                  autofocus: autofocus,
                  autofillHints: autofillHints,
                  textCapitalization: textCapitalization,
                  textInputAction: textInputAction,
                  style: AppTextStyles.rowTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: label,
                    hintStyle: AppTextStyles.rowTitle.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  onChanged: onChanged,
                  onFieldSubmitted: onSubmitted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
