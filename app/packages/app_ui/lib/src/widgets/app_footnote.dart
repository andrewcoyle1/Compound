import 'package:app_ui/app_ui.dart';
import 'package:flutter/gestures.dart' show TapGestureRecognizer;

/// One sentence of an [AppFootnote], with an optional ⓘ link after it.
final class AppFootnoteLine {
  /// A sentence, and what its ⓘ opens.
  const new(this.text, {this.infoLabel, this.onInfo});

  /// The sentence, localized.
  final String text;

  /// What screen readers hear for the ⓘ, such as "About Calorie Target".
  final String? infoLabel;

  /// Opens the explanation; without it the line has no ⓘ.
  final VoidCallback? onInfo;
}

/// {@template app_footnote}
/// Small secondary notes under a section, one sentence a line, each
/// ending in an optional inline ⓘ in the accent that opens its
/// explanation, such as a method's sources. The ⓘ is a link within the
/// text, so it keeps the text's size and wraps with it.
/// {@endtemplate}
class AppFootnote extends StatefulWidget {
  /// {@macro app_footnote}
  const new({required this.lines, super.key});

  /// The sentences, in order.
  final List<AppFootnoteLine> lines;

  @override
  State<AppFootnote> createState() => _AppFootnoteState();
}

class _AppFootnoteState extends State<AppFootnote> {
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final tap in _taps) {
      tap.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _tap(int index, VoidCallback onInfo) {
    while (_taps.length <= index) {
      _taps.add(TapGestureRecognizer());
    }
    return _taps[index]..onTap = onInfo;
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.label.secondary(context);
    const glyph = AppSymbols.info;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final (index, line) in widget.lines.indexed) ...[
            if (index > 0) const TextSpan(text: '\n'),
            TextSpan(text: line.text),
            if (line.onInfo case final onInfo?) ...[
              const TextSpan(text: ' '),
              TextSpan(
                text: String.fromCharCode(glyph.codePoint),
                semanticsLabel: line.infoLabel,
                recognizer: _tap(index, onInfo),
                style: style.copyWith(
                  fontFamily: glyph.fontFamily,
                  package: glyph.fontPackage,
                  color: context.appColors.accentInk,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
