import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:quick_actions/quick_actions.dart' as plugin;

class _MockQuickActions extends Mock implements plugin.QuickActions;

void main() {
  group(PluginQuickActionsRepository, () {
    late _MockQuickActions quickActions;
    late PluginQuickActionsRepository repository;

    setUp(() {
      quickActions = _MockQuickActions();
      repository = PluginQuickActionsRepository(quickActions);
      when(() => quickActions.initialize(any())).thenAnswer((_) async {});
      when(() => quickActions.setShortcutItems(any())).thenAnswer((_) async {});
      when(quickActions.clearShortcutItems).thenAnswer((_) async {});
    });

    test('hands over taps on its own actions only', () async {
      final tapped = <QuickAction>[];
      await repository.initialize(tapped.add);
      final handler =
          verify(() => quickActions.initialize(captureAny())).captured.single
              as plugin.QuickActionHandler;
      handler('logMeal');
      handler('somethingElse');
      expect(tapped, [QuickAction.logMeal]);
    });

    test('offers the actions with their titles and icons', () async {
      await repository.show({
        QuickAction.startWorkout: 'Start Workout',
        QuickAction.logWeight: 'Log Weight',
      });
      final items =
          verify(() => quickActions.setShortcutItems(captureAny()))
                  .captured
                  .single
              as List<plugin.ShortcutItem>;
      expect(items.map((i) => (i.type, i.localizedTitle, i.icon)), [
        ('startWorkout', 'Start Workout', 'quick_action_start_workout'),
        ('logWeight', 'Log Weight', 'quick_action_log_weight'),
      ]);
      expect(QuickAction.logMeal.icon, 'quick_action_log_meal');
    });

    test('clears them', () async {
      await repository.clear();
      verify(quickActions.clearShortcutItems).called(1);
    });

    test('defaults to the plugin', () {
      expect(PluginQuickActionsRepository.new, returnsNormally);
    });
  });

  group(FakeQuickActionsRepository, () {
    test('records the actions and plays taps', () async {
      final repository = FakeQuickActionsRepository();
      final tapped = <QuickAction>[];
      repository.tap(QuickAction.logWeight);
      await repository.initialize(tapped.add);
      await repository.show({QuickAction.logMeal: 'Log Meal'});
      expect(repository.titles, {QuickAction.logMeal: 'Log Meal'});
      repository.tap(QuickAction.logWeight);
      expect(tapped, [QuickAction.logWeight]);
      await repository.clear();
      expect(repository.titles, isEmpty);
    });
  });
}
