import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';

/// [child] as the menu of [units], the [selected] one ticked (Swift
/// `UnitMenu`). [onSelected] hears every choice, the ticked one included.
class UnitMenu<T> extends StatelessWidget {
  const new({
    required this.units,
    required this.selected,
    required this.name,
    required this.onSelected,
    required this.child,
    this.semanticsLabel,
    super.key,
  });

  final List<T> units;
  final T selected;
  final String Function(T unit) name;
  final ValueChanged<T> onSelected;
  final Widget child;

  /// What a screen reader says for the menu, when [child] does not say it.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      button: true,
      // Its ink needs a Material, which a card's table does not have.
      child: Material(
        type: MaterialType.transparency,
        child: PopupMenuButton<T>(
          tooltip: '',
          onSelected: onSelected,
          itemBuilder: (_) => [
            for (final unit in units)
              CheckedPopupMenuItem<T>(
                value: unit,
                checked: unit == selected,
                child: Text(name(unit)),
              ),
          ],
          child: child,
        ),
      ),
    );
  }
}

/// How a new unit is applied: to what is shown, or to the open sets too.
enum UnitChange { displayOnly, convert }

/// Asks how a new unit is applied (`promptUnitChange`): Display Only,
/// Convert Values or Cancel (null).
Future<UnitChange?> askUnitChange(BuildContext context, String title) {
  final l10n = context.l10n;
  return showDialog<UnitChange>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(l10n.trackerUnitChangeMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.trackerCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(UnitChange.displayOnly),
          child: Text(l10n.trackerDisplayOnly),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(UnitChange.convert),
          child: Text(l10n.trackerConvertValues),
        ),
      ],
    ),
  );
}
