import 'package:app_ui/app_ui.dart';

/// {@template app_menu_item}
/// An item in a [PopupMenuButton]'s menu: an optional leading icon from
/// [AppSymbols] and its label, as Swift's `Label` in a `Menu`. A destructive
/// item (Delete, Discard) is drawn in `danger`.
///
/// For an option that is chosen or not, use [CheckedPopupMenuItem].
/// {@endtemplate}
class AppMenuItem<T> extends PopupMenuItem<T> {
  /// {@macro app_menu_item}
  new({
    required String label,
    required super.value,
    IconData? icon,
    bool isDestructive = false,
    super.key,
  }) : super(
         child: _Label(label: label, icon: icon, isDestructive: isDestructive),
       );
}

class _Label extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.isDestructive,
  });

  final String label;
  final IconData? icon;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? context.appColors.danger
        : Theme.of(context).colorScheme.onSurface;
    final icon = this.icon;
    return Row(
      spacing: AppSpacing.m,
      children: [
        if (icon != null)
          Icon(icon, size: AppIconSize.medium.of(context), color: color),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.rowTitle.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
