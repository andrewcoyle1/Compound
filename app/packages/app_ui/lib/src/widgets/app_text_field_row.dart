import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';

/// {@template app_text_field_row}
/// A text entry row in an [AppSection], as a Swift `Form`'s `TextField`:
/// the typed text in row type, and [label] as the placeholder while it is
/// empty. Screen readers hear [label] whether or not the row has text. It is
/// at least as tall as an [AppListRow] and grows with the text size.
///
/// With [minLines] or [maxLines] above one it is a multi-line field, such as
/// a note or a pasted label, drawn the same way: on the row's own surface,
/// with no fill or border of its own.
///
/// For a number, use [AppNumberField].
/// {@endtemplate}
class AppTextFieldRow extends StatelessWidget {
  /// {@macro app_text_field_row}
  const new({
    required this.label,
    this.onChanged,
    this.controller,
    this.initialValue,
    this.minLines,
    this.maxLines = 1,
    this.inputFormatters,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.sentences,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
    this.keyboardType,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.prefixText,
    this.suffixText,
    super.key,
  });

  /// What the field holds, localized: its placeholder and accessible name.
  final String label;

  /// Called on every edit with the text typed.
  final ValueChanged<String>? onChanged;

  /// Holds the text, for a caller that sets or reads it itself; then
  /// [initialValue] must be null.
  final TextEditingController? controller;

  /// The text the field starts with.
  final String? initialValue;

  /// The fewest lines the field shows, for a multi-line field.
  final int? minLines;

  /// The most lines the field grows to before it scrolls; null for no limit.
  final int? maxLines;

  /// Limits on what may be typed, such as a length.
  final List<TextInputFormatter>? inputFormatters;

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

  /// The keyboard, such as [TextInputType.url]; text by default.
  final TextInputType? keyboardType;

  /// Whether the keyboard corrects spelling; off for a code or a link.
  final bool autocorrect;

  /// Whether the keyboard suggests words; off for a username.
  final bool enableSuggestions;

  /// Text before the typed text once the field has focus or text, such as
  /// `@`.
  final String? prefixText;

  /// Text after the typed text once the field has focus or text, such as
  /// `%`.
  final String? suffixText;

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
                  controller: controller,
                  initialValue: initialValue,
                  minLines: minLines,
                  maxLines: maxLines,
                  inputFormatters: inputFormatters,
                  autofocus: autofocus,
                  autofillHints: autofillHints,
                  textCapitalization: textCapitalization,
                  textInputAction: textInputAction,
                  keyboardType: keyboardType,
                  autocorrect: autocorrect,
                  enableSuggestions: enableSuggestions,
                  style: AppTextStyles.rowTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                  // Collapsed, as `InputDecoration.collapsed`, which has no
                  // prefix or suffix.
                  decoration: InputDecoration(
                    hintText: label,
                    hintStyle: AppTextStyles.rowTitle.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    prefixText: prefixText,
                    suffixText: suffixText,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    border: InputBorder.none,
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
