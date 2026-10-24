import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/coach/view/coach_day_card.dart';
import 'package:compound/today/today.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

/// The top of today's chat: the date and the day's checklist, live, with
/// the weigh-in logged in place.
void main() {
  const uid = 'me';
  final now = DateTime.now();

  late AppBloc appBloc;
  late InMemoryBodyRepository body;

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: uid, isAnonymous: false)),
    );
    body = InMemoryBodyRepository(
      measurements: [
        BodyMeasurementEntry(
          id: 'w',
          authorId: uid,
          weightKg: 82.4,
          date: DateTime(now.year, now.month, now.day - 2, 7),
          source: WeightSource.manual,
          dateCreated: now,
        ),
      ],
    );
  });

  Future<void> pump(WidgetTester tester) async {
    final users = InMemoryUserRepository();
    await tester.pumpApp(
      BlocProvider(
        create: (_) => TodayBloc(
          workoutSessionRepository: InMemoryWorkoutSessionRepository(
            sessions: const [],
          ),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: body,
          userRepository: users,
          analyticsRepository: const AnalyticsRepository(),
          checkInRepository: InMemoryCheckInRepository(),
          uid: uid,
          firstWeekday: DateTime.monday,
        )..add(const TodaySubscriptionRequested()),
        child: const AppScaffold(
          body: SingleChildScrollView(child: CoachDayCard()),
        ),
      ),
      appBloc: appBloc,
      bodyRepository: body,
      userRepository: users,
    );
  }

  testWidgets('shows the date and the day, then logs the weigh-in in place', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(AppPlaceholder), findsOneWidget);
    await tester.pumpAndSettle();

    expect(
      find.text(AppFormat.date(now, style: AppDateStyle.weekdayDayMonthLong)),
      findsOneWidget,
    );
    expect(find.text('Your Day'), findsOneWidget);
    expect(find.text("Today's Weight"), findsOneWidget);

    await tester.enterText(find.byType(TextField), '81.9');
    await tester.pump();
    await tester.tap(find.text('Save Weigh-In'));
    await tester.pumpAndSettle();

    // Done today: the item ticks, and the field goes.
    expect(find.text("Today's Weight"), findsNothing);
    final saved = await tester.runAsync(
      () => body.watchMeasurements(uid).first,
    );
    expect(saved!.map((entry) => entry.weightKg), contains(81.9));
  });
}
