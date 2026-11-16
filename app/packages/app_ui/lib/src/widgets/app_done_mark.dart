import 'package:app_ui/app_ui.dart';

/// {@template app_done_mark}
/// The mark for something the user has done: a ticked task, a logged set, a
/// finished exercise. A volt disc with a black tick, the size of the
/// [AppSymbols.choiceUnselected] circle it replaces, so a row swaps one for
/// the other without moving.
///
/// Done is the accent, not `success` green, which is kept for system
/// messages (design-language.md). The tick carries the meaning where volt
/// is faint, on white. Decorative: the row or button around it says what
/// is done.
///
/// [AppDoneMark.toggle] is the empty circle until [done], and swaps between
/// the two with [AppIconSwap].
/// {@endtemplate}
class AppDoneMark extends StatelessWidget {
  /// {@macro app_done_mark}
  const new({this.size = AppIconSize.medium, super.key})
    : done = null,
      undoneColor = null;

  /// The empty circle while not [done], the mark once it is: a set's log
  /// button, a checklist's task.
  const new toggle({
    required bool this.done,
    this.size = AppIconSize.medium,
    this.undoneColor,
    super.key,
  });

  /// The size of the glyph box, as an icon's.
  final AppIconSize size;

  /// Whether the mark shows, for [AppDoneMark.toggle]; null for the mark
  /// alone.
  final bool? done;

  /// The empty circle's colour; the ColorScheme's `onSurfaceVariant` when
  /// null.
  final Color? undoneColor;

  @override
  Widget build(BuildContext context) {
    final done = this.done;
    if (done == null) return _mark(context);
    return AppIconSwap(
      value: done,
      child: done
          ? _mark(context)
          : Icon(
              AppSymbols.choiceUnselected,
              size: size.of(context),
              color:
                  undoneColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
            ),
    );
  }

  Widget _mark(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = size.of(context);
    // A Material circle glyph draws its circle 20 units across in a box of
    // 24.
    final diameter = box * 20 / 24;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: box,
        child: Center(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: const CircleBorder(),
              color: scheme.primary,
            ),
            child: SizedBox.square(
              dimension: diameter,
              child: Icon(
                AppSymbols.selected,
                size: diameter * 0.7,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
