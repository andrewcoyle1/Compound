import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

const _answer = '''
## What to try

Your trend is down **0.1 kg a week**, *slower* than planned.

- Log every meal for a week
- Weigh in each morning
  - before breakfast

3. Check in on `Sunday`
4. See [the method](https://example.com)

> Based on 37 weigh-ins.

---
~~old~~ new  
line''';

TextSpan _span(WidgetTester tester) =>
    tester.widget<SelectableText>(find.byType(SelectableText)).textSpan!;

/// Every leaf span with [text], so its style can be read.
TextSpan _leaf(WidgetTester tester, String text) {
  TextSpan? found;
  _span(tester).visitChildren((span) {
    if (span is TextSpan && span.text == text) found = span;
    return found == null;
  });
  return found!;
}

void main() {
  testWidgets('sets headings, lists and emphasis without their markers', (
    tester,
  ) async {
    await tester.pumpApp(const AppMarkdownText(_answer));

    expect(
      _span(tester).toPlainText(),
      'What to try\n\n'
      'Your trend is down 0.1 kg a week, slower than planned.\n\n'
      '• Log every meal for a week\n'
      '• Weigh in each morning\n'
      '    • before breakfast\n\n'
      '3. Check in on Sunday\n'
      '4. See the method\n\n'
      'Based on 37 weigh-ins.\n\n'
      'old new\nline',
    );
    expect(
      _leaf(tester, 'What to try').style?.fontSize,
      AppTextStyles.sectionTitle.fontSize,
    );
    expect(_leaf(tester, '0.1 kg a week').style?.fontWeight, FontWeight.w600);
    expect(_leaf(tester, 'slower').style?.fontStyle, FontStyle.italic);
    expect(_leaf(tester, 'Sunday').style?.fontFamily, 'monospace');
    expect(_leaf(tester, 'old').style?.decoration, TextDecoration.lineThrough);
    // A link is its text and nothing more.
    expect(_leaf(tester, 'the method').recognizer, isNull);
  });

  testWidgets('keeps a loose list on its lines, and takes a style', (
    tester,
  ) async {
    await tester.pumpApp(
      AppMarkdownText('- one\n\n- two', style: AppTextStyles.rowDetail),
    );

    expect(_span(tester).toPlainText(), '• one\n• two');
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).style,
      AppTextStyles.rowDetail,
    );
  });

  test('plainText reads as a screen reader should', () {
    expect(
      AppMarkdownText.plainText('**Bold** and _this_:\n\n1. one'),
      'Bold and this:\n\n1. one',
    );
    expect(AppMarkdownText.plainText(''), '');
  });

  group('AppMarkdownText golden', () {
    goldenStates('app_markdown_text', [
      ('Answer', const AppMarkdownText(_answer)),
      ('Plain', const AppMarkdownText('Just a sentence, as typed.')),
    ]);
  });
}
