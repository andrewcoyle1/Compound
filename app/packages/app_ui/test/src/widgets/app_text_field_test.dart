import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppTextField', () {
    testWidgets('passes its text input settings to the field', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      await tester.pumpApp(
        AppTextField(
          controller: controller,
          focusNode: focusNode,
          minLines: 2,
          maxLines: 4,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.send,
          textAlign: TextAlign.center,
          autofocus: true,
          autocorrect: false,
          textStyle: AppTextStyles.metric,
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode, focusNode);
      expect((field.minLines, field.maxLines), (2, 4));
      expect(field.keyboardType, TextInputType.number);
      expect(field.textCapitalization, TextCapitalization.words);
      expect(field.textInputAction, TextInputAction.send);
      expect(field.textAlign, TextAlign.center);
      expect(field.autofocus, isTrue);
      expect(field.autocorrect, isFalse);
      expect(field.style!.fontSize, AppTextStyles.metric.fontSize);
      await tester.enterText(find.byType(TextField), '12ab');
      expect(controller.text, '12');
    });

    testWidgets('starts with its value, reports edits and submits', (
      tester,
    ) async {
      final edits = <String>[];
      final submitted = <String>[];
      await tester.pumpApp(
        AppTextField(
          initialValue: 'Squat',
          textInputAction: TextInputAction.done,
          onChanged: edits.add,
          onSubmitted: submitted.add,
        ),
      );
      expect(find.text('Squat'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Bench');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(edits, ['Bench']);
      expect(submitted, ['Bench']);
    });

    testWidgets('shows its label, hint and helper, and is named by its '
        'label', (tester) async {
      await tester.pumpApp(
        const AppTextField(
          label: 'Note',
          hint: 'What happened?',
          helper: 'Only you see it.',
        ),
      );
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Only you see it.'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Note')), findsWidgets);
    });

    testWidgets('draws each style', (tester) async {
      await tester.pumpApp(
        const Column(
          children: [
            AppTextField(key: Key('boxed'), dense: true),
            AppTextField(key: Key('plain'), style: AppTextFieldStyle.plain),
            AppTextField(
              key: Key('composer'),
              style: AppTextFieldStyle.composer,
            ),
          ],
        ),
      );
      InputDecoration decoration(String key) => tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(TextField),
            ),
          )
          .decoration!;
      final colors = AppTheme.light.extension<AppColors>()!;
      expect(decoration('boxed').filled, isTrue);
      expect(decoration('boxed').isDense, isTrue);
      expect(decoration('boxed').fillColor, colors.raised);
      expect(decoration('plain').filled, isFalse);
      expect(decoration('plain').border, InputBorder.none);
      expect(decoration('composer').fillColor, colors.surface);
      expect(
        decoration('composer').border,
        isA<OutlineInputBorder>().having(
          (border) => border.borderRadius,
          'radius',
          const BorderRadius.all(Radius.circular(AppRadius.l)),
        ),
      );
    });
  });

  group('AppTextField golden', () {
    goldenStates('app_text_field', [
      (
        'Boxed, label and hint',
        const AppTextField(label: 'Name', hint: 'Dumbbell'),
      ),
      (
        'Boxed, with text and helper',
        const AppTextField(
          label: 'Note',
          initialValue: 'Left knee sore',
          helper: 'Shown on this workout only.',
        ),
      ),
      (
        'Composer',
        const AppTextField(
          hint: 'Ask the coach',
          style: AppTextFieldStyle.composer,
          maxLines: 5,
          minLines: 1,
        ),
      ),
      (
        'Plain, in a card',
        const AppCard(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: AppTextField(
              hint: 'Add a comment',
              style: AppTextFieldStyle.plain,
            ),
          ),
        ),
      ),
    ]);
  });
}
