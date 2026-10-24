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

  group('streaming', () {
    String streamed(String data) =>
        AppMarkdownText.plainText(data, streaming: true);

    test('closes bold, italic and code left open at the end', () {
      expect(streamed('Your trend is **down 0.4'), 'Your trend is down 0.4');
      expect(streamed('It is _slower '), 'It is slower');
      expect(streamed('Check in on `Sun'), 'Check in on Sun');
      expect(streamed('**Bold and _both'), 'Bold and both');
      expect(streamed('**Bold and `code'), 'Bold and code');
    });

    test('drops a marker that has nothing after it yet', () {
      expect(streamed('Your trend is **'), 'Your trend is');
      expect(streamed('**Bold*'), 'Bold');
      expect(streamed('Check `'), 'Check');
    });

    test('leaves closed markers, lists, words and fences alone', () {
      expect(streamed('**Done** and _done_'), 'Done and done');
      expect(streamed('* one\n* two'), '• one\n• two');
      expect(streamed('snake_case_name'), 'snake_case_name');
      expect(streamed('a `**` b'), 'a ** b');
      expect(streamed('```\nfenced'), 'fenced\n');
      expect(streamed('2 * 3 = 6'), '2 * 3 = 6');
    });

    test('only while streaming', () {
      expect(AppMarkdownText.plainText('**open'), '**open');
    });

    testWidgets('can be plain text, not selectable', (tester) async {
      await tester.pumpApp(
        const AppMarkdownText('**Bold**', selectable: false),
      );
      expect(find.byType(SelectableText), findsNothing);
      expect(find.text('Bold', findRichText: true), findsOneWidget);
    });

    testWidgets('draws the closed text', (tester) async {
      await tester.pumpApp(
        const AppMarkdownText('Trend **down', streaming: true),
      );
      expect(_leaf(tester, 'down').style?.fontWeight, FontWeight.w600);
    });
  });

  group('AppMarkdownText golden', () {
    goldenStates('app_markdown_text', [
      ('Answer', const AppMarkdownText(_answer)),
      ('Plain', const AppMarkdownText('Just a sentence, as typed.')),
      (
        'Streaming',
        const AppMarkdownText(
          'Your trend is **down 0.4 kg a week**, *a little fast',
          streaming: true,
        ),
      ),
    ]);
  });
}
