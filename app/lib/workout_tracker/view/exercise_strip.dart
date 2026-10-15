import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/view/exercise_image.dart';
import 'package:training_rules/training_rules.dart' as r;

/// The workout's map along the top: one tile per block, in order, each
/// filling with its working sets; a tap opens it on the card. Add Exercise
/// ends it (`ExerciseStrip`).
class ExerciseStrip extends StatelessWidget {
  const new({
    required this.items,
    required this.onSelected,
    required this.onAddExercise,
    super.key,
  });

  final List<r.StripItem> items;
  final ValueChanged<String> onSelected;
  final VoidCallback onAddExercise;

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
          for (final item in items)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.s),
              child: _Tile(
                item: item,
                side: side,
                onTap: () => onSelected(item.id),
              ),
            ),
          SizedBox(
            width: side,
            child: Align(
              alignment: Alignment.topCenter,
              child: IconButton.filledTonal(
                tooltip: l10n.trackerAddExercise,
                onPressed: onAddExercise,
                icon: const Icon(AppSymbols.add),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const new({required this.item, required this.side, required this.onTap});

  final r.StripItem item;
  final double side;
  final VoidCallback onTap;

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
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.s)),
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
                        ? BorderSide(color: scheme.primary, width: 2)
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
                                  style: AppTextStyles.label.copyWith(
                                    color: scheme.onPrimary,
                                    fontWeight: FontWeight.w700,
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
                color: item.isComplete ? context.appColors.success : null,
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
