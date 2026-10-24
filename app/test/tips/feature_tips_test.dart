import 'package:app_ui/app_ui.dart';
import 'package:compound/tips/feature_tips.dart';
import 'package:device_store/device_store.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

void main() {
  late InMemoryDeviceStore store;
  late AnalyticsRecorder analytics;
  late FeatureTips tips;

  setUp(() {
    store = InMemoryDeviceStore({'other': true});
    analytics = AnalyticsRecorder();
    tips = FeatureTips(store: store, analytics: analytics);
  });

  group('FeatureTips', () {
    test('a tip is seen once shown, and both events carry its id', () {
      expect(tips.isSeen(FeatureTips.mealSwipe), isFalse);

      tips.shown('NutritionView', FeatureTips.mealSwipe);
      expect(tips.isSeen(FeatureTips.mealSwipe), isTrue);
      expect(tips.isSeen(FeatureTips.setSwipe), isFalse);

      tips.dismissed('NutritionView', FeatureTips.mealSwipe);
      expect(analytics.names, [
        'NutritionView_Tip_Shown',
        'NutritionView_Tip_Dismissed',
      ]);
      expect(analytics.parameters('NutritionView_Tip_Dismissed'), {
        'tip_id': 'meal_swipe',
      });
    });

    test('reset forgets the tips seen and nothing else', () {
      tips
        ..shown('A', FeatureTips.setSwipe)
        ..shown('A', FeatureTips.metricChart)
        ..reset();
      expect(tips.isSeen(FeatureTips.setSwipe), isFalse);
      expect(tips.isSeen(FeatureTips.metricChart), isFalse);
      expect(store.keys, {'other'});
    });
  });

  group('ScreenTips', () {
    Widget screen() => const ScreenTips(
      screen: 'NutritionView',
      tips: [FeatureTips.mealSwipe],
      child: AppTip(
        id: FeatureTips.mealSwipe,
        title: 'Log a meal again',
        message: 'Swipe a food right.',
        child: Text('Breakfast'),
      ),
    );

    testWidgets('without FeatureTips, shows no tip', (tester) async {
      await tester.pumpApp(screen());
      await tester.pump(AppTipScope.settle);
      await tester.pumpAndSettle();
      expect(find.byType(AppTipScope), findsNothing);
      expect(find.byType(AppTipCallout), findsNothing);
    });

    testWidgets('shows a new tip once, and logs it by screen', (tester) async {
      await tester.pumpApp(
        RepositoryProvider<FeatureTips?>.value(value: tips, child: screen()),
      );
      await tester.pump(AppTipScope.settle);
      await tester.pumpAndSettle();
      expect(find.text('Swipe a food right.'), findsOneWidget);
      expect(tips.isSeen(FeatureTips.mealSwipe), isTrue);

      await tester.tap(find.text('Got It'));
      await tester.pumpAndSettle();
      expect(find.byType(AppTipCallout), findsNothing);
      expect(analytics.names, [
        'NutritionView_Tip_Shown',
        'NutritionView_Tip_Dismissed',
      ]);
    });
  });
}
