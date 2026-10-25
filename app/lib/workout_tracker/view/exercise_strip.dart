import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/view/exercise_image.dart';
import 'package:flutter/semantics.dart';
import 'package:training_rules/training_rules.dart' as r;

/// The workout's map along the top: one tile per block, in order, each
/// filling with its working sets; a tap opens it on the card. Add Exercise
/// ends it (`ExerciseStrip`).
class ExerciseStrip extends StatelessWidget {
  const new({
    required this.items,
    required this.onSelected,
    required this.onAddExercise,
    this.onDoNext,
    this.onDoLater,
    this.onMove,
    super.key,
  });

  final List<r.StripItem> items;
  final ValueChanged<String> onSelected;
  final VoidCallback onAddExercise;

  /// A block moved straight after the card's, or to the end.
  final ValueChanged<String>? onDoNext;
  final ValueChanged<String>? onDoLater;

  /// A block moved to an index among the blocks: Move Earlier and Later.
  final void Function(String blockId, int index)? onMove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5);
    final side = scale.scale(48);
    return SizedBox(
      height: side + scale.scale(20) + AppSpacing.s * 2,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.s,
        ),
        children: [
          for (final (index, item) in items.indexed)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.s),
              child: _Tile(
                key: ValueKey('strip-${item.id}'),
                item: item,
                side: side,
                onTap: () => onSelected(item.id),
                actions: _actions(l10n, item, index),
              ),
            ),
          SizedBox(
            width: side,
            child: Align(
              alignment: Alignment.topCenter,
              child: AppIconButton(
                icon: AppSymbols.add,
                semanticLabel: l10n.trackerAddExercise,
                onPressed: onAddExercise,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Do Next and Do Later, for a block neither on the card nor done, then
  /// a step either way: what a long press and a screen reader offer
  /// (`stripMenu`, `stripActions`).
  List<(IconData, String, VoidCallback)> _actions(
    AppLocalizations l10n,
    r.StripItem item,
    int index,
  ) => [
    if (!item.isCurrent && !item.isComplete) ...[
      if (onDoNext case final doNext?)
        (AppSymbols.doNext, l10n.trackerDoNext, () => doNext(item.id)),
      if (onDoLater case final doLater?)
        (AppSymbols.doLater, l10n.trackerDoLater, () => doLater(item.id)),
    ],
    if (onMove case final move?) ...[
      if (index > 0)
        (
          AppSymbols.moveEarlier,
          l10n.trackerMoveEarlier,
          () => move(item.id, index - 1),
        ),
      if (index < items.length - 1)
        (
          AppSymbols.moveLater,
          l10n.trackerMoveLater,
          () => move(item.id, index + 1),
        ),
    ],
  ];
}

class _Tile extends StatelessWidget {
  const new({
    required this.item,
    required this.side,
    required this.onTap,
    this.actions = const [],
    super.key,
  });

  final r.StripItem item;
  final double side;
  final VoidCallback onTap;
  final List<(IconData, String, VoidCallback)> actions;

  Future<void> _menu(BuildContext context) async {
    final chosen = await showAppSheet<VoidCallback>(
      context: context,
      size: AppSheetSize.compact,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppSection(
            children: [
              for (final (icon, label, action) in actions)
                AppListRowButton(
                  title: label,
                  icon: icon,
                  accessory: null,
                  onPressed: () => Navigator.of(context).pop(action),
                ),
            ],
          ),
        ],
      ),
    );
    chosen?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final letter = item.supersetLetter;
    final names = item.names.join(', ');
    return Semantics(
      button: true,
      selected: item.isCurrent,
      label: letter == null ? names : '${l10n.supersetLabel(letter)}: $names',
      value: l10n.trackerStripProgress(
        item.doneWorkingSets,
        item.totalWorkingSets,
      ),
      excludeSemantics: true,
      customSemanticsActions: {
        for (final (_, label, action) in actions)
          CustomSemanticsAction(label: label): action,
      },
      child: AppPressable(
        onTap: onTap,
        onLongPress: actions.isEmpty ? null : () => _menu(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.s)),
        ),
        child: SizedBox(
          width: side,
          child: Column(
            spacing: AppSpacing.xs,
            children: [
              DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: ShapeDecoration(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadius.s),
                    ),
                    side: item.isCurrent
                        ? BorderSide(
                            color: context.appColors.accentInk,
                            width: 2,
                          )
                        : BorderSide.none,
                  ),
                ),
                child: ClipRSuperellipse(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadius.s),
                  ),
                  child: SizedBox.square(
                    dimension: side,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ExerciseImage.named(
                          name: item.names.first,
                          image: item.imageNames.first,
                        ),
                        if (letter != null)
                          Align(
                            alignment: AlignmentDirectional.topStart,
                            child: ColoredBox(
                              color: context.appColors.superset,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                ),
                                child: Text(
                                  letter,
                                  style: AppTextStyles.label.semibold.copyWith(
                                    color: scheme.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              LinearProgressIndicator(
                value: item.fraction,
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.s),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
