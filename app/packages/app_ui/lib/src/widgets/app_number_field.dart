import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';

/// {@template app_number_field}
/// A number entry row: a decimal field that selects its text on focus, with
/// its unit as trailing secondary text, or as a menu when the user can pick
/// the unit. With a [label] the label leads and the field trails.
///
/// Accepts `.` or `,` as the decimal separator and reports `null` for empty
/// or unreadable input.
/// {@endtemplate}
class AppNumberField extends StatefulWidget {
  /// {@macro app_number_field}
  const new({
    required this.value,
    required this.onChanged,
    this.prompt,
    this.label,
    this.unit,
    super.key,
  }) : units = const [],
       onUnitChanged = null,
       unitsLabel = null;

  /// A field whose unit the user picks from [units]; [unit] is the current
  /// one. [unitsLabel] names the menu for screen readers, such as `Unit`.
  const new units({
    required this.value,
    required this.onChanged,
    required String this.unit,
    required this.units,
    required ValueChanged<String> this.onUnitChanged,
    required String this.unitsLabel,
    this.prompt,
    this.label,
    super.key,
  });

  /// The number shown, or `null` for an empty field.
  final double? value;

  /// Called on every edit with the number typed, or `null`.
  final ValueChanged<double?> onChanged;

  /// The hint in an empty field.
  final String? prompt;

  /// A label before the field.
  final String? label;

  /// The unit's symbol, such as `kg`.
  final String? unit;

  /// The units to choose from, by symbol.
  final List<String> units;

  /// Called with the unit picked.
  final ValueChanged<String>? onUnitChanged;

  /// The unit menu's name for screen readers.
  final String? unitsLabel;

  /// Reads a typed number: `null` when empty, unreadable or not finite.
  static double? parse(String text) {
    final number = double.tryParse(text.trim().replaceAll(',', '.'));
    return number != null && number.isFinite ? number : null;
  }

  @override
  State<AppNumberField> createState() => _AppNumberFieldState();
}

class _AppNumberFieldState extends State<AppNumberField> {
  late final _controller = TextEditingController(text: _text(widget.value));
  final _focusNode = FocusNode();

  static String _text(double? value) {
    if (value == null) return '';
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  @override
  void initState() {
    super.initState();
    // Focus listeners run after the focusing tap has placed the caret, so
    // this selection is the one that sticks.
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) _selectAll();
    });
  }

  @override
  void didUpdateWidget(AppNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (AppNumberField.parse(_controller.text) != widget.value) {
      _controller.text = _text(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _selectAll() => _controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: _controller.text.length,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = widget.label;
    final unit = widget.unit;
    final onUnitChanged = widget.onUnitChanged;
    final secondaryStyle = AppTextStyles.rowTitle.copyWith(
      color: scheme.onSurfaceVariant,
    );

    // At accessibility sizes the label goes above the value, as an
    // AppListRow's value does: side by side, half a row broke a label
    // such as "Rest between sets" in the middle of a word.
    final stacked =
        label != null &&
        MediaQuery.textScalerOf(context)
                .scale(AppTextStyles.rowTitle.fontSize!) >=
            AppTextStyles.rowTitle.fontSize! *
                AppListRow.accessibilityTextScale;

    Widget field = TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
      textAlign: label == null || stacked ? TextAlign.start : TextAlign.end,
      style: AppTextStyles.rowTitle.copyWith(color: scheme.onSurface),
      decoration: InputDecoration.collapsed(
        hintText: widget.prompt,
        hintStyle: secondaryStyle,
      ),
      onChanged: (text) => widget.onChanged(AppNumberField.parse(text)),
    );
    if (label != null) {
      final labelText = Text(
        label,
        style: AppTextStyles.rowTitle.copyWith(color: scheme.onSurface),
      );
      field = MergeSemantics(
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [labelText, field],
              )
            : Row(
                // The label and the field each get up to half the row, so
                // space a short label leaves goes between them and the
                // value stays beside the unit.
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                spacing: AppSpacing.m,
                children: [
                  // Flexible, so a long label wraps rather than pushing the
                  // field out of the row.
                  Flexible(child: labelText),
                  Expanded(child: field),
                ],
              ),
      );
    }

    final Widget? unitView;
    if (onUnitChanged != null) {
      unitView = PopupMenuButton<String>(
        tooltip: widget.unitsLabel,
        initialValue: unit,
        onSelected: onUnitChanged,
        itemBuilder: (context) => [
          for (final option in widget.units)
            PopupMenuItem(value: option, child: Text(option)),
        ],
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppControlSize.row,
            minHeight: AppControlSize.row,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: AppSpacing.xxs,
            children: [
              Text(
                unit!,
                style: AppTextStyles.rowTitle.copyWith(
                  color: context.appColors.accentInk,
                ),
              ),
              Icon(
                AppSymbols.choose,
                size: AppIconSize.small.of(context),
                color: context.appColors.accentInk,
              ),
            ],
          ),
        ),
      );
    } else if (unit != null) {
      unitView = Text(unit, style: secondaryStyle);
    } else {
      unitView = null;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppControlSize.row),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        child: Row(
          spacing: AppSpacing.s,
          children: [
            Expanded(child: field),
            ?unitView,
          ],
        ),
      ),
    );
  }
}
