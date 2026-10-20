import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../../helpers/helpers.dart';

const uid = 'user-1';

/// Every event, as `(name, type)`.
class RecordingAnalytics extends Fake implements AnalyticsRepository {
  final events = <(String, LogType)>[];

  List<String> get names => [for (final (name, _) in events) name];

  @override
  void trackEvent(LoggableEvent event) =>
      events.add((event.eventName, event.type));

  @override
  void trackScreenView(LoggableEvent event) => trackEvent(event);
}

/// The in-memory repository, remembering every food log settings save;
/// [failing] makes saves throw.
class SpyNutritionRepository extends InMemoryNutritionRepository {
  new({super.foodLogSettings});

  final saved = <FoodLogSettings>[];
  bool failing = false;

  @override
  Future<void> saveFoodLogSettings(FoodLogSettings settings) async {
    if (failing) throw StateError('refused');
    saved.add(settings);
    await super.saveFoodLogSettings(settings);
  }
}

/// The in-memory repository, remembering every strategy settings save.
class SpyCheckInRepository extends InMemoryCheckInRepository {
  new({super.settings});

  final saved = <NutritionStrategySettings>[];

  @override
  Future<void> saveStrategySettings(NutritionStrategySettings settings) async {
    saved.add(settings);
    await super.saveStrategySettings(settings);
  }
}

/// A tall view, so a whole settings list is built at once.
void useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 9000);
  addTearDown(tester.view.reset);
}

/// An [AppBloc] with [uid] signed in.
AppBloc signedInAppBloc() {
  final bloc = MockAppBloc();
  when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  when(
    () => bloc.state,
  ).thenReturn(const AppAuthenticated(AuthUser(uid: uid, isAnonymous: false)));
  return bloc;
}
