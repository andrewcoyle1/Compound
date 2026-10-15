import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/training/training.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

void main() {
  late AppBloc appBloc;

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  group(TrainingPage, () {
    testWidgets('offers the search and the Library', (tester) async {
      when(() => appBloc.state).thenReturn(
        const AppAuthenticated(AuthUser(uid: 'friend', isAnonymous: false)),
      );
      await tester.pumpApp(const TrainingPage(), appBloc: appBloc);
      await tester.pump();

      expect(find.widgetWithText(AppBar, 'Training'), findsOneWidget);
      expect(find.byType(ProfileButton), findsOneWidget);
      expect(find.text('Exercises and workouts'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Workouts'), findsOneWidget);
      expect(find.text('Exercises'), findsOneWidget);
      expect(find.text('Workout History'), findsOneWidget);
    });

    testWidgets('shows nothing when signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(const TrainingPage(), appBloc: appBloc);
      expect(find.text('Library'), findsNothing);
    });
  });
}
