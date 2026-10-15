import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/progress/logic/progress_overview.dart';
import 'package:compound/settings/general/cubit/customise_analytics_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../recorded_analytics.dart';

class _MockBodyRepository extends Mock implements BodyRepository;

void main() {
  late BodyRepository body;
  late RecordedAnalytics analytics;
  late StreamController<AnalyticsSettings> stored;
  late List<Map<String, Object?>> saved;

  setUpAll(() => registerFallbackValue(const AnalyticsSettings(authorId: 'x')));

  setUp(() {
    body = _MockBodyRepository();
    analytics = RecordedAnalytics();
    stored = StreamController<AnalyticsSettings>();
    saved = [];
    when(() => body.watchAnalyticsSettings('uid'))
        .thenAnswer((_) => stored.stream);
    when(() => body.saveAnalyticsSettings(any())).thenAnswer((invocation) {
      saved.add(
        (invocation.positionalArguments.single as AnalyticsSettings)
            .toFirestore(),
      );
      return Future.value();
    });
  });

  tearDown(() => stored.close());

  Future<CustomiseAnalyticsCubit> build({
    List<String> hidden = const [],
    int? dailyStepGoal,
  }) async {
    final cubit = CustomiseAnalyticsCubit(
      body: body,
      analytics: analytics,
      uid: 'uid',
    );
    stored.add(
      AnalyticsSettings(
        authorId: 'uid',
        hiddenSectionIds: hidden,
        dailyStepGoal: dailyStepGoal,
      ),
    );
    await pumpEventQueue();
    return cubit;
  }

  test('every section starts visible', () async {
    final cubit = await build();
    expect(ProgressSection.values.every(cubit.state.isVisible), isTrue);
    expect(cubit.state.hiddenCount, 0);
  });

  test('hiding one section does not unhide another', () async {
    final cubit = await build();
    await cubit.visibilityChanged(ProgressSection.habits, isVisible: false);
    await cubit.visibilityChanged(ProgressSection.nutrition, isVisible: false);
    await cubit.visibilityChanged(ProgressSection.exercises, isVisible: false);
    expect(saved.map((s) => s['hidden_section_ids']), [
      ['habits'],
      ['habits', 'nutrition'],
      ['habits', 'nutrition', 'exercises'],
    ]);
    expect(cubit.state.hiddenCount, 3);
    expect(cubit.state.isVisible(ProgressSection.bodyMetrics), isTrue);
  });

  test('hiding a section twice records it once', () async {
    final cubit = await build();
    await cubit.visibilityChanged(ProgressSection.habits, isVisible: false);
    await cubit.visibilityChanged(ProgressSection.habits, isVisible: false);
    expect(saved, hasLength(2));
    expect(saved.last['hidden_section_ids'], ['habits']);
    expect(cubit.state.hiddenCount, 1);
  });

  test('showing a section saves the whole document, step goal kept', () async {
    final cubit = await build(hidden: ['habits'], dailyStepGoal: 6000);
    await cubit.visibilityChanged(ProgressSection.habits, isVisible: true);
    expect(saved.single, {
      'id': 'analytics_settings',
      'author_id': 'uid',
      'hidden_section_ids': <String>[],
      'daily_step_goal': 6000,
    });
  });

  test('the last visible section cannot be hidden', () async {
    final cubit = await build(
      hidden: [
        for (final section in ProgressSection.values)
          if (section != ProgressSection.habits) section.id,
      ],
    );
    expect(cubit.state.canHide(ProgressSection.habits), isFalse);
    expect(cubit.state.canHide(ProgressSection.nutrition), isTrue);
  });

  test('a section can be hidden while others remain', () async {
    final cubit = await build();
    expect(ProgressSection.values.every(cubit.state.canHide), isTrue);
  });

  test('Show All brings every section back in one save, keeping ids this '
      'build does not know', () async {
    final cubit = await build(
      hidden: ['habits', 'nutrition', 'exercises', 'from_a_newer_build'],
    );
    await cubit.showAllPressed();
    expect(cubit.state.hiddenCount, 0);
    expect(saved, hasLength(1));
    expect(saved.single['hidden_section_ids'], ['from_a_newer_build']);
  });

  test('changes are tracked under the Swift names', () async {
    final cubit = await build();
    await cubit.visibilityChanged(ProgressSection.habits, isVisible: false);
    await cubit.showAllPressed();
    expect(analytics.events.first, [
      'CustomiseAnalyticsView_SectionVisibility_Changed',
      {'section': 'habits', 'is_visible': false},
      LogType.analytic,
    ]);
    expect(analytics.names.where((name) => !name.contains('_Save_')), [
      'CustomiseAnalyticsView_SectionVisibility_Changed',
      'CustomiseAnalyticsView_ShowAll_Press',
    ]);
  });

  test('a failed save says so', () async {
    when(() => body.saveAnalyticsSettings(any())).thenThrow(StateError('no'));
    final cubit = await build();
    await cubit.visibilityChanged(ProgressSection.habits, isVisible: false);
    expect(cubit.state.saveFailed, isTrue);
    expect(analytics.events.last[0], 'CustomiseAnalyticsView_Save_Fail');
    expect(analytics.events.last[2], LogType.severe);
  });

  test('a save that fails after closing emits nothing', () async {
    final refusal = Completer<void>();
    when(() => body.saveAnalyticsSettings(any()))
        .thenAnswer((_) => refusal.future);
    final cubit = await build();
    final saving = cubit.visibilityChanged(
      ProgressSection.habits,
      isVisible: false,
    );
    await cubit.close();
    refusal.completeError(StateError('no'));
    await saving;
    expect(cubit.state.saveFailed, isFalse);
  });

  test('appearing and disappearing are tracked', () async {
    (await build())
      ..appeared()
      ..disappeared();
    expect(analytics.screenViews, ['CustomiseAnalyticsView_Appear']);
    expect(analytics.names, ['CustomiseAnalyticsView_Disappear']);
  });
}
