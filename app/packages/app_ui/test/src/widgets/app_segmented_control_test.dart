import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

const List<AppSegment<String>> _units = [
  AppSegment(value: 'kg', label: 'Metric'),
  AppSegment(value: 'lb', label: 'Imperial', semanticLabel: 'Pounds'),
];

void _goldenChanged(Object? _) {}

void main() {
  group('AppSegmentedControl', () {
    testWidgets('reports a new choice, with the selection haptic', (
      tester,
    ) async {
      final haptics = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String?);
          }
          return null;
        },
      );
      final chosen = <String>[];
      await tester.pumpApp(
        AppSegmentedControl<String>(
          segments: _units,
          selected: 'kg',
          onChanged: chosen.add,
        ),
      );
      await tester.tap(find.text('Metric'));
      expect(chosen, isEmpty);
      await tester.tap(find.text('Imperial'));
      expect(chosen, ['lb']);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('announces each option and which is selected', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        AppSegmentedControl<String>(
          segments: _units,
          selected: 'kg',
          onChanged: (_) {},
        ),
      );
      expect(find.semantics.byLabel('Metric'), findsOne);
      expect(
        tester.getSemantics(find.text('Metric')),
        isSemantics(
          label: 'Metric',
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Pounds')),
        isSemantics(isSelected: false, isButton: true),
      );
      handle.dispose();
    });

    testWidgets('has a 32 pt track in a 44 pt target', (tester) async {
      await tester.pumpApp(
        Center(
          child: AppSegmentedControl<String>(
            segments: _units,
            selected: 'kg',
            onChanged: (_) {},
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(AppSegmentedControl<String>)).height,
        44,
      );
      final track = find.descendant(
        of: find.byType(AppSegmentedControl<String>),
        matching: find.byType(DecoratedBox),
      );
      expect(tester.getSize(track.first).height, 32);
    });

    testWidgets('with nothing chosen it draws no thumb', (tester) async {
      await tester.pumpApp(
        AppSegmentedControl<String>(
          segments: _units,
          selected: null,
          onChanged: (_) {},
        ),
      );
      expect(find.byType(AnimatedAlign), findsNothing);
    });

    testWidgets('one option sits centred', (tester) async {
      await tester.pumpApp(
        AppSegmentedControl<String>(
          segments: const [AppSegment(value: 'kg', label: 'Metric')],
          selected: 'kg',
          onChanged: (_) {},
        ),
      );
      expect(
        tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment,
        AlignmentDirectional.center,
      );
    });

    testWidgets('disabled, it ignores taps', (tester) async {
      await tester.pumpApp(
        const AppSegmentedControl<String>(
          segments: _units,
          selected: 'kg',
          onChanged: null,
        ),
      );
      await tester.tap(find.text('Imperial'));
      final text = tester.widget<Text>(find.text('Imperial'));
      expect(text.style?.color, AppTheme.light.colorScheme.onSurfaceVariant);
    });
  });

  group('AppSegmentedControl golden', () {
    const units = [
      AppSegment(value: 'kg', label: 'kg'),
      AppSegment(value: 'lb', label: 'lb'),
    ];
    const periods = [
      AppSegment(value: 0, label: 'Week'),
      AppSegment(value: 1, label: 'Month'),
      AppSegment(value: 2, label: 'Year'),
    ];
    goldenStates('app_segmented_control', [
      (
        'Two, first selected',
        const AppSegmentedControl(
          segments: units,
          selected: 'kg',
          onChanged: _goldenChanged,
        ),
      ),
      (
        'Three, middle selected',
        const AppSegmentedControl(
          segments: periods,
          selected: 1,
          onChanged: _goldenChanged,
        ),
      ),
      (
        'None selected',
        const AppSegmentedControl(
          segments: periods,
          selected: null,
          onChanged: _goldenChanged,
        ),
      ),
      (
        'Disabled',
        const AppSegmentedControl(
          segments: periods,
          selected: 2,
          onChanged: null,
        ),
      ),
      (
        'Long labels',
        const AppSegmentedControl(
          segments: [
            AppSegment(value: 0, label: 'Maintain weight'),
            AppSegment(value: 1, label: 'Lose fat slowly'),
          ],
          selected: 0,
          onChanged: _goldenChanged,
        ),
      ),
    ]);
  });
}
