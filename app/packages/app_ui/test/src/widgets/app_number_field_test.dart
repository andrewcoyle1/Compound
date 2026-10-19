import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

class _Host extends StatefulWidget {
  const new();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  double? value = 80;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppNumberField(value: value, onChanged: (_) {}),
      TextButton(
        onPressed: () => setState(() => value = 82.5),
        child: const Text('Set'),
      ),
    ],
  );
}

void _goldenChanged(Object? _) {}

void main() {
  group('AppNumberField.parse', () {
    test('reads either decimal separator', () {
      expect(AppNumberField.parse('82.5'), 82.5);
      expect(AppNumberField.parse(' 82,5 '), 82.5);
    });

    test('is null for empty, unreadable or infinite input', () {
      expect(AppNumberField.parse(''), isNull);
      expect(AppNumberField.parse('.'), isNull);
      expect(AppNumberField.parse('9' * 400), isNull);
    });
  });

  group('AppNumberField', () {
    testWidgets('shows the value and reports edits', (tester) async {
      final edits = <double?>[];
      await tester.pumpApp(
        AppNumberField(value: 80, onChanged: edits.add, unit: 'kg'),
      );
      expect(find.text('80'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '82,5');
      await tester.enterText(find.byType(TextField), '');
      expect(edits, [82.5, null]);
    });

    testWidgets('keeps only digits and separators', (tester) async {
      final edits = <double?>[];
      await tester.pumpApp(AppNumberField(value: null, onChanged: edits.add));
      await tester.enterText(find.byType(TextField), '1a2');
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('shows a new value from outside', (tester) async {
      await tester.pumpApp(const _Host());
      await tester.tap(find.text('Set'));
      await tester.pump();
      expect(find.text('82.5'), findsOneWidget);
    });

    testWidgets('selects everything on the focusing tap only', (tester) async {
      await tester.pumpApp(
        AppNumberField(value: 1250, onChanged: (_) {}, prompt: 'Weight'),
      );
      final field = find.byType(TextField);
      TextSelection selection() =>
          tester.widget<TextField>(field).controller!.selection;

      await tester.tap(field);
      await tester.pump();
      expect(selection(), const TextSelection(baseOffset: 0, extentOffset: 4));

      await tester.pump(const Duration(seconds: 1));
      await tester.tap(field);
      await tester.pump();
      expect(selection().isCollapsed, isTrue);
    });

    testWidgets('with a label, the label leads and reads with the field', (
      tester,
    ) async {
      await tester.pumpApp(
        AppNumberField(value: 70, onChanged: (_) {}, label: 'Body weight'),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).textAlign,
        TextAlign.end,
      );
      expect(
        tester.getSemantics(find.byType(TextField)),
        isSemantics(label: 'Body weight', isTextField: true),
      );
    });

    testWidgets('offers its units in a menu', (tester) async {
      String? picked;
      await tester.pumpApp(
        AppNumberField.units(
          value: 70,
          onChanged: (_) {},
          unit: 'kg',
          units: const ['kg', 'lb'],
          onUnitChanged: (unit) => picked = unit,
          unitsLabel: 'Unit',
        ),
      );
      expect(find.byTooltip('Unit'), findsOneWidget);
      await tester.tap(find.text('kg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('lb').last);
      await tester.pumpAndSettle();
      expect(picked, 'lb');
    });
  });

  testWidgets('puts its label above the value at accessibility sizes', (
    tester,
  ) async {
    await tester.pumpApp(
      const AppNumberField(
        value: 2,
        onChanged: _goldenChanged,
        label: 'Rest between sets',
      ),
      textScale: 2,
    );
    final label = tester.getRect(find.text('Rest between sets'));
    final value = tester.getRect(find.byType(TextField));
    expect(value.top, greaterThanOrEqualTo(label.bottom));
    expect(
      tester.widget<TextField>(find.byType(TextField)).textAlign,
      TextAlign.start,
    );
  });

  group('AppNumberField golden', () {
    Widget card(Widget field) => AppCard(child: field);
    goldenStates('app_number_field', [
      (
        'Empty, with prompt',
        card(
          const AppNumberField(
            value: null,
            onChanged: _goldenChanged,
            prompt: 'Weight',
            unit: 'kg',
          ),
        ),
      ),
      (
        'Value and unit',
        card(
          const AppNumberField(
            value: 81.4,
            onChanged: _goldenChanged,
            unit: 'kg',
          ),
        ),
      ),
      (
        'Labelled',
        card(
          const AppNumberField(
            value: 12,
            onChanged: _goldenChanged,
            label: 'Reps',
          ),
        ),
      ),
      (
        'Unit menu',
        card(
          const AppNumberField.units(
            value: 32.5,
            onChanged: _goldenChanged,
            label: 'Waist',
            unit: 'in',
            units: ['cm', 'in'],
            onUnitChanged: _goldenChanged,
            unitsLabel: 'Units',
          ),
        ),
      ),
      (
        'Long label',
        card(
          const AppNumberField(
            value: 2,
            onChanged: _goldenChanged,
            label: 'Rest between sets',
            unit: 'min',
          ),
        ),
      ),
    ]);
  });
}
