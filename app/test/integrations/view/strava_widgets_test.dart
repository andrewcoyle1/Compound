import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strava_repository/strava_repository.dart';

import '../../helpers/helpers.dart';

class _MockStravaCubit extends MockCubit<StravaState> implements StravaCubit;

void main() {
  // A run on Tuesday 13 October 2026, a ride the Saturday before.
  final activities = sampleStravaActivities(DateTime(2026, 10, 14, 12));
  late StravaCubit cubit;

  setUp(() {
    cubit = _MockStravaCubit();
    when(() => cubit.state).thenReturn(StravaState(activities: activities));
  });

  group(StravaWeekSection, () {
    testWidgets("adds up the week's runs and rides", (tester) async {
      await tester.pumpApp(
        Material(
          child: StravaWeekSection(
            weekStart: DateTime(2026, 10, 12),
            distanceUnit: DistanceUnitPreference.kilometers,
          ),
        ),
        stravaCubit: cubit,
      );
      expect(find.text('From Strava'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('6.2\u00a0km'), findsOneWidget);
      expect(find.text('33:00'), findsOneWidget);
    });

    testWidgets('shows nothing for a week without any', (tester) async {
      await tester.pumpApp(
        Material(
          child: StravaWeekSection(
            weekStart: DateTime(2026, 9, 28),
            distanceUnit: null,
          ),
        ),
        stravaCubit: cubit,
      );
      expect(find.text('From Strava'), findsNothing);
    });
  });

  group(StravaYearSection, () {
    testWidgets("adds up the year's and lists the latest, in miles", (
      tester,
    ) async {
      final links = LinkRecorder();
      await tester.pumpApp(
        Material(
          child: SingleChildScrollView(
            child: StravaYearSection(
              distanceUnit: DistanceUnitPreference.miles,
              now: DateTime(2026, 10, 14),
            ),
          ),
        ),
        stravaCubit: cubit,
        linkOpener: links,
      );
      expect(find.text('Strava This Year'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('24\u00a0mi'), findsOneWidget);
      expect(find.text('View on Strava'), findsNWidgets(2));

      await tester.tap(find.text('Evening Ride'));
      expect(links.opened, [
        Uri.parse('https://www.strava.com/activities/1002'),
      ]);
    });

    testWidgets('shows nothing in a year without any', (tester) async {
      await tester.pumpApp(
        Material(
          child: StravaYearSection(distanceUnit: null, now: DateTime(2027, 2)),
        ),
        stravaCubit: cubit,
      );
      expect(find.text('Strava This Year'), findsNothing);
    });
  });
}
