import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppSearchField', () {
    testWidgets('is a 44 pt capsule on the surface colour', (tester) async {
      await tester.pumpApp(
        AppSearchField(hint: 'Search', clearLabel: 'Clear', onChanged: (_) {}),
      );
      expect(tester.getSize(find.byType(AppSearchField)).height, 44);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AppSearchField),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, AppColors.light.surface);
      expect(material.shape, isA<StadiumBorder>());
    });

    testWidgets('announces its hint as the field label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        AppSearchField(
          hint: 'Search exercises',
          clearLabel: 'Clear',
          onChanged: (_) {},
        ),
      );
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(isTextField: true, label: 'Search exercises'),
      );
      handle.dispose();
    });

    testWidgets('clears, reports empty and unfocuses', (tester) async {
      final changes = <String>[];
      await tester.pumpApp(
        AppSearchField(
          hint: 'Search',
          clearLabel: 'Clear',
          initialValue: 'bench',
          onChanged: changes.add,
        ),
      );
      expect(find.text('bench'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear'));
      await tester.pump();
      expect(changes, ['']);
      expect(find.text('bench'), findsNothing);
      expect(find.byTooltip('Clear'), findsNothing);

      await tester.enterText(find.byType(TextField), 'squat');
      expect(changes, ['', 'squat']);
    });

    testWidgets('shows the clear button while focused', (tester) async {
      final focus = FocusNode();
      final controller = TextEditingController();
      addTearDown(focus.dispose);
      addTearDown(controller.dispose);
      await tester.pumpApp(
        AppSearchField(
          hint: 'Search',
          clearLabel: 'Cancel',
          controller: controller,
          focusNode: focus,
          onChanged: (_) {},
        ),
      );
      expect(find.byTooltip('Cancel'), findsNothing);
      focus.requestFocus();
      await tester.pump();
      expect(find.byTooltip('Cancel'), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    });

    testWidgets('grows with the text', (tester) async {
      await tester.pumpApp(
        AppSearchField(
          hint: 'Search',
          clearLabel: 'Clear',
          autofocus: true,
          onChanged: (_) {},
        ),
        textScale: 2,
      );
      expect(
        tester.getSize(find.byType(AppSearchField)).height,
        greaterThan(44),
      );
    });
  });
}
