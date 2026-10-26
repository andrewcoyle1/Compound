import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/log_measurement/log_measurement.dart';
import 'package:compound/progress/logic/body_metrics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockLogMeasurementBloc
    extends MockBloc<LogMeasurementEvent, LogMeasurementState>
    implements LogMeasurementBloc;

class _MockGoRouter extends Mock implements GoRouter;

void main() {
  late LogMeasurementBloc bloc;

  setUpAll(() => registerFallbackValue(const LogMeasurementStarted()));

  setUp(() {
    bloc = _MockLogMeasurementBloc();
    when(() => bloc.state).thenReturn(
      LogMeasurementState(
        kind: BodyMeasurementKind.waist,
        date: DateTime(2026, 10, 15, 19, 45),
        centimetres: 80,
        centimetresTenths: 5,
        inches: 31,
        status: LogMeasurementStatus.ready,
      ),
    );
  });

  Future<void> pumpView(WidgetTester tester) => tester.pumpApp(
    InheritedGoRouter(
      goRouter: _MockGoRouter(),
      child: BlocProvider.value(value: bloc, child: const LogMeasurementView()),
    ),
  );

  group(LogMeasurementView, () {
    testWidgets('shows the reading with its unit', (tester) async {
      await pumpView(tester);
      expect(find.text('Waist Circumference'), findsOneWidget);
      expect(find.text('80.5'), findsOneWidget);
      expect(find.text('cm'), findsOneWidget);
    });

    testWidgets('sends what the user changes', (tester) async {
      await pumpView(tester);

      await tester.enterText(find.byType(TextField), '84.3');
      await tester.pump();
      verify(() => bloc.add(const LogMeasurementWholeChanged(84))).called(1);
      verify(() => bloc.add(const LogMeasurementTenthsChanged(3))).called(1);

      await tester.tap(find.text('cm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('in').last);
      await tester.pumpAndSettle();
      verify(
        () => bloc.add(
          const LogMeasurementUnitChanged(LengthUnitPreference.inches),
        ),
      ).called(1);

      await tester.tap(find.byTooltip('Save'));
      verify(() => bloc.add(const LogMeasurementSaveRequested())).called(1);
    });

    testWidgets('keeps a reading outside the span from being saved', (
      tester,
    ) async {
      await pumpView(tester);
      await tester.enterText(find.byType(TextField), '300');
      await tester.pump();
      final save = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, AppSymbols.selected),
      );
      expect(save.onPressed, isNull);
      verifyNever(() => bloc.add(any(that: isA<LogMeasurementWholeChanged>())));
    });
  });
}
