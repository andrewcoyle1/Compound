import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/app/app.dart';
import 'package:compound/launch/launch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

void main() {
  const user = AuthUser(uid: 'uid', isAnonymous: true);
  late AppBloc appBloc;

  setUp(() => appBloc = MockAppBloc());

  testWidgets('waits with a labelled spinner while the profile loads', (
    tester,
  ) async {
    whenListen(
      appBloc,
      const Stream<AppState>.empty(),
      initialState: const AppAuthenticated(user),
    );
    await tester.pumpApp(const LaunchPage(), appBloc: appBloc);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
  });

  testWidgets('offers Try Again and Sign Out when it cannot be read', (
    tester,
  ) async {
    whenListen(
      appBloc,
      const Stream<AppState>.empty(),
      initialState: const AppAuthenticated(
        user,
        profileStatus: AppProfileStatus.failure,
      ),
    );
    await tester.pumpApp(const LaunchPage(), appBloc: appBloc, textScale: 2);
    expect(find.text("Your profile couldn't be loaded."), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    verify(() => appBloc.add(const AppProfileRetryRequested())).called(1);
    await tester.tap(find.text('Sign Out'));
    verify(() => appBloc.add(const AppSignOutPressed())).called(1);
    expect(tester.takeException(), isNull);
    expect(find.byType(AppSpinner), findsNothing);
  });
}
