import 'package:app_ui/app_ui.dart';

/// The kind of an [AppInlineMessage].
enum AppInlineMessageKind {
  /// Something failed. Drawn in `danger`.
  error,

  /// Something to watch. Drawn in `warning`.
  warning,

  /// A neutral note. Drawn in secondary text.
  info,
}

/// {@template app_inline_message}
/// A one-line status message inside a form, sheet or scanner: an icon in the
/// kind's colour beside the text. Use it in place of raw red or orange text.
///
/// The text stays in a readable text colour, because the status colours fail
/// 4.5:1 on white; the icon carries the colour. Screen readers hear one
/// element, "[kindLabel], [text]".
/// {@endtemplate}
class AppInlineMessage extends StatelessWidget {
  /// {@macro app_inline_message}
  const new({
    required this.kind,
    required this.text,
    required this.kindLabel,
    super.key,
  });

  /// The message's kind.
  final AppInlineMessageKind kind;

  /// The message, localized or from the system.
  final String text;

  /// The kind's name, localized, such as `Error`.
  final String kindLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final (icon, color, textColor) = switch (kind) {
      AppInlineMessageKind.error => (
        AppSymbols.error,
        colors.danger,
        scheme.onSurface,
      ),
      AppInlineMessageKind.warning => (
        AppSymbols.warning,
        colors.warning,
        scheme.onSurface,
      ),
      AppInlineMessageKind.info => (
        AppSymbols.info,
        scheme.onSurfaceVariant,
        scheme.onSurfaceVariant,
      ),
    };
    final style = AppTextStyles.rowDetail.copyWith(color: textColor);
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.s,
        children: [
          Icon(
            icon,
            color: color,
            size: MediaQuery.textScalerOf(context).scale(style.fontSize!),
            semanticLabel: kindLabel,
          ),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
