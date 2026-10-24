import 'package:app_ui/app_ui.dart';

/// {@template app_floating_button}
/// A capsule button floating over scrolling content, such as a chat's
/// Jump to Latest: [icon] and [label] in the text colour, raised off the
/// canvas and off a card alike as a snack bar is, on the dialog's surface
/// with its hairline and a soft shadow. At least 44 pt tall; it grows with
/// the text size.
///
/// Place it with a `Stack`; it sizes to its label.
/// {@endtemplate}
class AppFloatingButton extends StatelessWidget {
  /// {@macro app_floating_button}
  const new({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// The glyph before the label, from [AppSymbols].
  final IconData icon;

  /// What the button does, localized.
  final String label;

  /// Called when tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppTextStyles.rowDetail.semibold.copyWith(
      color: scheme.onSurface,
    );
    const shape = StadiumBorder();
    return Semantics(
      button: true,
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: shape.copyWith(
          side: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
        shadowColor: scheme.shadow.withValues(alpha: 0.12),
        elevation: AppSpacing.xs,
        child: InkWell(
          onTap: onPressed,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppControlSize.row),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpacing.xs,
                children: [
                  Icon(
                    icon,
                    color: scheme.onSurface,
                    size: MediaQuery.textScalerOf(context)
                        .scale(style.fontSize!),
                  ),
                  Flexible(child: Text(label, style: style)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
