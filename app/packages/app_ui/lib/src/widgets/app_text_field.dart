import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';

/// How an [AppTextField] is drawn.
enum AppTextFieldStyle {
  /// On the `raised` fill with `AppRadius.m` corners: a field on its own in
  /// a sheet or dialog.
  boxed,

  /// No fill or border: a field laid out inside a row, a bar or a title.
  plain,

  /// On the `surface` fill with `AppRadius.l` corners: a message composer
  /// over the canvas.
  composer,
}

/// {@template app_text_field}
/// A text field outside a form row: in a sheet or dialog, a composer, or
/// inside a row the screen lays out itself. The typed text is in row type
/// unless [textStyle] says otherwise.
///
/// [label] floats above the text once there is some, and names the field
/// for screen readers; [hint] is the placeholder; [helper] explains the
/// field below it and wraps.
///
/// In an `AppSection`, use `AppTextFieldRow`; for a search,
/// `AppSearchField`; for a number with a unit, `AppNumberField`.
/// {@endtemplate}
class AppTextField extends StatelessWidget {
  /// {@macro app_text_field}
  const new({
    this.controller,
    this.focusNode,
    this.initialValue,
    this.label,
    this.hint,
    this.helper,
    this.style = AppTextFieldStyle.boxed,
    this.textStyle,
    this.dense = false,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.autocorrect = true,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  /// Holds the text, for a caller that sets or reads it itself; then
  /// [initialValue] must be null.
  final TextEditingController? controller;

  /// The field's focus, for a caller that moves it.
  final FocusNode? focusNode;

  /// The text the field starts with.
  final String? initialValue;

  /// What the field holds, localized.
  final String? label;

  /// The placeholder, localized.
  final String? hint;

  /// A note under the field, localized.
  final String? helper;

  /// How the field is drawn.
  final AppTextFieldStyle style;

  /// The typed text's style, from [AppTextStyles], such as
  /// [AppTextStyles.metric] for an amount; [AppTextStyles.rowTitle] by
  /// default. Always in the text colour.
  final TextStyle? textStyle;

  /// Less padding, for a small field in a table.
  final bool dense;

  /// The fewest lines the field shows, for a multi-line field.
  final int? minLines;

  /// The most lines the field grows to before it scrolls; null for no limit.
  final int? maxLines;

  /// The keyboard, such as [TextInputType.number]; text by default.
  final TextInputType? keyboardType;

  /// Limits on what may be typed, such as digits only.
  final List<TextInputFormatter>? inputFormatters;

  /// How the keyboard capitalises.
  final TextCapitalization textCapitalization;

  /// The keyboard's action button.
  final TextInputAction? textInputAction;

  /// Where the text sits in the field.
  final TextAlign textAlign;

  /// Whether the field takes focus when it first appears.
  final bool autofocus;

  /// Whether the keyboard corrects spelling.
  final bool autocorrect;

  /// Called on every edit with the text typed.
  final ValueChanged<String>? onChanged;

  /// Called when the keyboard's action button is pressed.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      initialValue: initialValue,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      textAlign: textAlign,
      autofocus: autofocus,
      autocorrect: autocorrect,
      style: (textStyle ?? AppTextStyles.rowTitle).copyWith(
        color: scheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        // Never cut short.
        helperMaxLines: 10,
        isDense: dense,
        filled: style != AppTextFieldStyle.plain,
        fillColor: style == AppTextFieldStyle.composer
            ? context.appColors.surface
            : null,
        border: switch (style) {
          AppTextFieldStyle.boxed => null,
          AppTextFieldStyle.plain => InputBorder.none,
          AppTextFieldStyle.composer => const OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.l)),
          ),
        },
      ),
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
    );
  }
}
