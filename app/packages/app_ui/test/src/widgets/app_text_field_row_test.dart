import 'package:app_ui/app_ui.dart';
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
    ]);
  });
}
