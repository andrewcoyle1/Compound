import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPicker;
import 'package:flutter/widgets.dart';

/// One wheel of whole numbers, opening on [selected] (or the first value
/// when it isn't one of [values]). Screen readers hear its [label] and the
/// row shown, and swipe up or down to adjust it.
class NumberWheel extends StatefulWidget {
  const new({
    required this.label,
    required this.values,
    required this.selected,
    required this.itemLabel,
    required this.onChanged,
    super.key,
  });

  final String label;
  final List<int> values;
  final int selected;
  final String Function(int value) itemLabel;
  final ValueChanged<int> onChanged;

  @override
  State<NumberWheel> createState() => _NumberWheelState();
}

class _NumberWheelState extends State<NumberWheel> {
  late final _controller = FixedExtentScrollController(
    initialItem: widget.values
        .indexOf(widget.selected)
        .clamp(0, widget.values.length - 1),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        label: widget.label,
        child: CupertinoPicker(
          scrollController: _controller,
          itemExtent: MediaQuery.textScalerOf(context).scale(32),
          onSelectedItemChanged: (index) =>
              widget.onChanged(widget.values[index]),
          children: [
            for (final value in widget.values)
              Center(child: Text(widget.itemLabel(value))),
          ],
        ),
      ),
    );
  }
}
