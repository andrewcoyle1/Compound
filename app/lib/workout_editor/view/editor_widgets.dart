import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show WorkoutEditorRules;

/// A title with a smaller line under it, as Swift's `navigationSubtitle`.
class const EditorTitle({
  required final String title,
  required final String subtitle,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.rowDetail.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// What shows behind a row swiped away.
class const DeleteBackground({required final String label, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.danger,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: AppSpacing.l),
          child: Icon(
            AppSymbols.delete,
            semanticLabel: label,
            color: Theme.of(context).colorScheme.onError,
          ),
        ),
      ),
    );
  }
}

/// A set number or RIR in a capsule that grows with its text.
class const NumberBadge(final String text, {super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: scheme.surfaceContainerHighest,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            text,
            style: AppTextStyles.rowDetail.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rep count typed as digits: at least one, or empty for none.
class RepsField extends StatefulWidget {
  const new({
    required this.value,
    required this.hint,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final int? value;
  final String hint;
  final String label;
  final ValueChanged<int?> onChanged;

  @override
  State<RepsField> createState() => _RepsFieldState();
}

class _RepsFieldState extends State<RepsField> {
  late final _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      child: TextField(
        controller: _controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(hintText: widget.hint, isDense: true),
        onChanged: (text) =>
            widget.onChanged(WorkoutEditorRules.typedReps(text)),
      ),
    );
  }
}

/// A menu of [choices] over [child], the [value] ticked. A null choice can
/// be picked too, which a plain `PopupMenuButton` cannot.
class ChoiceMenu<T> extends StatelessWidget {
  const new({
    required this.value,
    required this.choices,
    required this.title,
    required this.onSelected,
    required this.tooltip,
    required this.child,
    super.key,
  });

  final T value;
  final List<T> choices;
  final String Function(T) title;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<(T,)>(
      tooltip: tooltip,
      initialValue: (value,),
      onSelected: (choice) {
        unawaited(HapticFeedback.selectionClick());
        onSelected(choice.$1);
      },
      itemBuilder: (_) => [
        for (final choice in choices)
          CheckedPopupMenuItem(
            value: (choice,),
            checked: choice == value,
            child: Text(title(choice)),
          ),
      ],
      child: child,
    );
  }
}

/// A count with buttons to step it within [min] and [max] (Swift
/// `Stepper`).
class const CountStepper({
  required final String title,
  required final int value,
  required final int min,
  required final int max,
  required final ValueChanged<int> onChanged,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppListRow(
      title: title,
      accessory: AppListRowCustom(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(AppSymbols.decrease),
              tooltip: l10n.editorDecrease,
              onPressed: value > min ? () => onChanged(value - 1) : null,
            ),
            IconButton(
              icon: const Icon(AppSymbols.increase),
              tooltip: l10n.editorIncrease,
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}
