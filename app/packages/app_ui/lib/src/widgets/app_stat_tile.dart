import 'package:app_ui/app_ui.dart';

/// {@template app_stat_tile}
/// An [AppStat] on its own tile: padded, full width, on an [AppCard] with
/// [AppCardStyle.tile], or [AppCardStyle.tinted] when [tint] is set.
/// {@endtemplate}
class AppStatTile extends StatelessWidget {
  /// {@macro app_stat_tile}
  const new({
    required this.value,
    required this.label,
    this.icon,
    this.size = AppStatSize.medium,
    this.alignment = CrossAxisAlignment.start,
    this.tint,
    super.key,
  });

  /// See [AppStat.value].
  final String value;

  /// See [AppStat.label].
  final String label;

  /// See [AppStat.icon].
  final IconData? icon;

  /// See [AppStat.size].
  final AppStatSize size;

  /// See [AppStat.alignment].
  final CrossAxisAlignment alignment;

  /// Tints the tile and the icon.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final tint = this.tint;
    return AppCard(
      style: tint == null ? AppCardStyle.tile : AppCardStyle.tinted(tint),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: SizedBox(
          width: double.infinity,
          child: AppStat(
            value: value,
            label: label,
            icon: icon,
            size: size,
            alignment: alignment,
            tint: tint,
          ),
        ),
      ),
    );
  }
}
