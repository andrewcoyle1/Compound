// Screenshots of every screen in the staging flavor, light and dark, for a
// pull request's before and after (ui-contract.md rule 8). Not part of the
// unit tests: run it with scripts/flutter-screenshots.sh.
import 'package:compound/main_staging.dart' as app;
import 'package:compound/shell/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

/// A comma-separated list of screen names, to shoot only those.
const _only = String.fromEnvironment('SHOTS_ONLY');

/// The run with a workout under way (`STAGING_WORKOUT`), which shoots only
/// [_workoutScreens].
const _workoutRun = bool.fromEnvironment('SHOTS_WORKOUT');

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Each screen by the Swift app's STARTSCREEN name, with its route in the
/// staging sample data.
final _screens = <(String, String)>[
  ('TODAY', '/today'),
  ('TRAINING', '/training'),
  ('NUTRITION', '/nutrition'),
  ('ANALYTICS', '/progress'),
  ('SOCIAL', '/social'),
  ('NOTIFICATIONS', '/social/notifications'),
  ('WEEKLY_REVIEW', '/today/weekly-review'),
  ('WORKOUTS', '/training/workouts'),
  ('TEMPLATE_DETAIL', '/training/workouts/user-workout-upper'),
  ('EXERCISES', '/training/exercises'),
  ('EXERCISE_DETAIL', '/training/exercises/system-barbell-bench-press'),
  ('WORKOUT_HISTORY', '/training/history'),
  ('SESSION_DETAIL', '/training/history/sample-session-push-a'),
  ('MACROCYCLES', '/training/macrocycles'),
  ('MACROCYCLE_DETAIL', '/training/macrocycles/sample-macrocycle'),
  ('PROGRAM_LIBRARY', '/training/mesocycles'),
  ('CREATE_PROGRAM', '/training/create-mesocycle'),
  ('MUSCLE_BALANCE', '/progress/muscle-balance'),
  ('CREATE_EXERCISE', '/create-exercise'),
  ('CREATE_WORKOUT', '/training/create-workout'),
  ('CHALLENGES', '/challenges/new'),
  ('SCALE_WEIGHT', '/progress/scale-weight'),
  ('MEASUREMENT_DETAIL', '/progress/body-metrics/waist'),
  ('LOG_MEASUREMENT', '/log-measurement/waist'),
  ('RECIPE_DETAIL', '/nutrition/recipes/sample-recipe-overnight-oats'),
  ('FOOD_DETAIL', '/nutrition/foods/sample-food-rolled-oats'),
  (
    'MEAL_DETAIL',
    '/nutrition/meal/sample-meal-'
        '${_day(DateTime.now().subtract(const Duration(days: 1)))}-0',
  ),
  ('RECIPES', '/nutrition/recipes'),
  ('FOODS', '/nutrition/foods'),
  ('CREATE_FOOD', '/create-food'),
  ('BODY_METRICS', '/progress/body-metrics'),
  ('PROGRESS_PHOTOS', '/progress/body-metrics/photos'),
  ('NUTRITION_ANALYTICS', '/progress/nutrition-analytics'),
  ('LOG_WEIGHT', '/log-weight'),
  ('OWN_PROFILE', '/people/mock_user_123'),
  ('PROFILE_COVER', '/profile'),
  ('SETTINGS', '/profile/settings'),
  ('EDIT_PROFILE', '/profile/edit'),
  ('NOTIFICATION_SETTINGS', '/profile/settings/notifications'),
  ('SIRI', '/profile/settings/siri'),
  ('DELETE_ACCOUNT', '/profile/settings/delete-account'),
  ('GYM_PROFILES', '/profile/settings/gym-profiles'),
  ('USERNAME', '/username'),
  ('SOCIAL_PROFILE', '/people/user1'),
  ('COMMENTS', '/sessions/user1/user1-sample-session-push-b/comments'),
  ('SHARED_ITEM', '/shares/sample-share-template'),
  ('CHALLENGE_DETAIL', '/challenges/mock_challenge_1'),
  ('PAYWALL', '/paywall'),
  // Shot a screen at a time, top to bottom: GALLERY-01-light.png and on.
  (_gallery, '/profile/settings/developer/gallery'),
];

/// The component gallery (`ui-contract.md` rule 7), which is many screens
/// long.
const _gallery = 'GALLERY';

/// The screens that need a workout under way, which every other screen
/// would then show in its tab bar.
final _workoutScreens = <(String, String)>[
  ('WORKOUT_TRACKER', '/workout'),
  ('SET_KEYBOARD', '/workout?keypad=1'),
  ('TAB_ACCESSORY_REST', '/today'),
];

/// Lets streams, timers and images land without waiting for spinners to
/// stop, which `pumpAndSettle` would.
Future<void> _settle(WidgetTester tester, {int ticks = 14}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
  }
  await tester.pump();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screens', (tester) async {
    final onError = FlutterError.onError;
    await app.main();
    FlutterError.onError = onError;
    await _settle(tester, ticks: 30);
    final router = GoRouter.of(tester.element(find.byType(AppShell)));
    final dispatcher = tester.platformDispatcher;
    addTearDown(dispatcher.clearPlatformBrightnessTestValue);

    for (final (name, location) in _workoutRun ? _workoutScreens : _screens) {
      if (_only.isNotEmpty && !_only.split(',').contains(name)) continue;
      router.go(location);
      await _settle(tester);
      // The reminder offer would cover every later screen; answer it.
      final notNow = find.text('Not Now');
      if (notNow.evaluate().isNotEmpty) {
        await tester.tap(notNow.first);
        await _settle(tester);
        router.go(location);
        await _settle(tester);
      }
      for (final brightness in Brightness.values.reversed) {
        dispatcher.platformBrightnessTestValue = brightness;
        await _settle(tester, ticks: 4);
        if (name == _gallery) {
          await _shootPages(tester, binding, name, brightness);
          continue;
        }
        await binding.takeScreenshot('$name-${brightness.name}');
      }
    }
  });
}

/// Shoots the longest vertical scroll view on screen a page at a time.
Future<void> _shootPages(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
  Brightness brightness,
) async {
  final position = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .map((state) => state.position)
      .where((p) => p.axis == Axis.vertical)
      .reduce((a, b) => a.maxScrollExtent >= b.maxScrollExtent ? a : b);
  final step = position.viewportDimension * 0.9;
  for (var page = 1, offset = 0.0; ; page++, offset += step) {
    position.jumpTo(offset.clamp(0, position.maxScrollExtent));
    await _settle(tester, ticks: 2);
    final number = page.toString().padLeft(2, '0');
    await binding.takeScreenshot('$name-$number-${brightness.name}');
    if (offset >= position.maxScrollExtent) break;
  }
  position.jumpTo(0);
}
