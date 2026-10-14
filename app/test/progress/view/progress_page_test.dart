import 'package:app_ui/app_ui.dart';
import 'package:compound/progress/progress.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

class _MockGoRouter extends Mock implements GoRouter;

void main() {
  group(ProgressPage, () {
    testWidgets('opens each weight screen by name', (tester) async {
      final router = _MockGoRouter();
      when(() => router.goNamed(any())).thenReturn(null);
      await tester.pumpApp(
        InheritedGoRouter(goRouter: router, child: const ProgressPage()),
      );
      expect(find.widgetWithText(AppBar, 'Progress'), findsOneWidget);

      await tester.tap(find.text('Scale Weight'));
      verify(() => router.goNamed(WeightMetric.scaleWeight.name)).called(1);
      await tester.tap(find.text('Weight Trend'));
      verify(() => router.goNamed(WeightMetric.weightTrend.name)).called(1);
    });
  });
}
