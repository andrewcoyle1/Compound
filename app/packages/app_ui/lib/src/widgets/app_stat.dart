import 'package:app_ui/app_ui.dart';

/// The size of an [AppStat]'s value.
enum AppStatSize {
  /// [AppTextStyles.metricSmall].
  small(AppTextStyles.metricSmall),

  /// [AppTextStyles.metric].
  medium(AppTextStyles.metric),

  /// [AppTextStyles.metricLarge].
  large(AppTextStyles.metricLarge);

  new(this.style);

  /// The value's text style.
  final TextStyle style;
}

/// {@template app_stat}
/// A value above its label, with an optional leading icon.
///
/// [value] and [label] are shown verbatim: pass localized text. Screen readers
/// read the pair as one element, "label, value".
/// {@endtemplate}
class AppStat extends StatelessWidget {
  /// {@macro app_stat}
  const new({
    required this.value,
    required this.label,
    this.icon,
    this.size = AppStatSize.medium,
    this.alignment = CrossAxisAlignment.start,
    this.tint,
    super.key,
  });

  /// The formatted value, such as `82.5 kg`.
  final String value;

  /// What the value is, such as `Weight`.
  final String label;

  /// An icon before the value.
  final IconData? icon;

  /// The value's size.
  final AppStatSize size;

  /// How the value and label line up.
  final CrossAxisAlignment alignment;

  /// Colours the icon. Without it the icon is `onSurfaceVariant`.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = this.icon;
    return Semantics(
      container: true,
      label: label,
      value: value,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xxs,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xs,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  color: tint ?? scheme.onSurfaceVariant,
                  size: MediaQuery.textScalerOf(context)
                      .scale(size.style.fontSize!),
                ),
              Text(value, style: size.style),
            ],
          ),
          Text(
            label,
            style: AppTextStyles.label.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
