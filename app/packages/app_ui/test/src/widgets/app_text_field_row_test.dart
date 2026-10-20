import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void _goldenChanged(String _) {}

void main() {
  group('AppTextFieldRow', () {
    testWidgets('shows the label as a placeholder while empty', (tester) async {
      await tester.pumpApp(
        AppTextFieldRow(label: 'First name', onChanged: (_) {}),
      );
      expect(find.text('First name'), findsOneWidget);
      expect(
        tester.getSize(find.byType(AppTextFieldRow)).height,
        greaterThanOrEqualTo(AppControlSize.listRow),
      );
    });

    testWidgets('starts with its value, reports edits and submits', (
      tester,
    ) async {
      final edits = <String>[];
      final submitted = <String>[];
      await tester.pumpApp(
        AppTextFieldRow(
          label: 'Last name',
          initialValue: 'Cooper',
          autofocus: true,
          autofillHints: const [AutofillHints.familyName],
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onChanged: edits.add,
          onSubmitted: submitted.add,
        ),
      );
      expect(find.text('Cooper'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);
      expect(field.textCapitalization, TextCapitalization.words);
      expect(field.autofillHints, [AutofillHints.familyName]);
      await tester.enterText(find.byType(TextField), 'Coyle');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(edits, ['Coyle']);
      expect(submitted, ['Coyle']);
    });

    testWidgets('a multi-line field takes its lines, controller and limits, '
        'with no fill of its own', (tester) async {
      final controller = TextEditingController(text: 'Energy 380 kcal');
      addTearDown(controller.dispose);
      await tester.pumpApp(
        AppSection(
          children: [
            AppTextFieldRow(
              label: 'Label text',
              controller: controller,
              minLines: 4,
              maxLines: 10,
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
            ),
          ],
        ),
        textScale: 2,
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.minLines, 4);
      expect(field.maxLines, 10);
      expect(field.decoration!.filled, isNot(isTrue));
      await tester.enterText(
        find.byType(TextField),
        'Energy 380 kcal Protein 30 g',
      );
      expect(controller.text, 'Energy 380 kcal Prot');
      expect(tester.takeException(), isNull);
    });

    testWidgets('is named by its label with text in it', (tester) async {
      await tester.pumpApp(
        AppTextFieldRow(
          label: 'First name',
          initialValue: 'Alice',
          onChanged: (_) {},
        ),
      );
      expect(find.bySemanticsLabel(RegExp('First name')), findsWidgets);
    });
  });

  group('AppTextFieldRow golden', () {
    Widget card(Widget field) => AppSection(children: [field]);
    goldenStates('app_text_field_row', [
      (
        'Empty',
        card(
          const AppTextFieldRow(label: 'First name', onChanged: _goldenChanged),
        ),
      ),
      (
        'With text',
        card(
          const AppTextFieldRow(
            label: 'First name',
            initialValue: 'Alice',
            onChanged: _goldenChanged,
          ),
        ),
      ),
      (
        'Multi-line',
        card(
          const AppTextFieldRow(
            label: 'Label text',
            minLines: 4,
            maxLines: 10,
            onChanged: _goldenChanged,
          ),
        ),
      ),
    ]);
  });
}
