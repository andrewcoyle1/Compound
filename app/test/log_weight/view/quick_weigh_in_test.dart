import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/log_weight/view/quick_weigh_in.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const uid = 'me';
  final now = DateTime(2026, 10, 15, 7);

  late AppBloc appBloc;
  late InMemoryBodyRepository body;
  late List<AppHaptic> haptics;

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
          date: now.subtract(const Duration(days: 1)),
          source: WeightSource.manual,
          dateCreated: now,
        ),
      ],
    );
    haptics = [];
    AppHaptics.debugPlay = haptics.add;
  });
  tearDown(() => AppHaptics.debugPlay = null);

  Future<void> pump(WidgetTester tester, {bool hasProfile = true}) async {
    await tester.pumpApp(
      const AppScaffold(body: SingleChildScrollView(child: QuickWeighIn())),
      appBloc: appBloc,
      bodyRepository: body,
      userRepository: InMemoryUserRepository(
        users: {
          if (hasProfile)
            uid: UserModel(userId: uid, creationDate: DateTime(2026)),
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder save() => find.text('Save Weigh-In');

  testWidgets('opens on the latest weigh-in and saves the weight typed', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text("Today's Weight"), findsOneWidget);
    expect(find.text('82.4'), findsOneWidget);
    expect(find.text('kg'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '81.6');
    await tester.pump();
    await tester.tap(save());
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(
      () => body.watchMeasurements(uid).first,
    );
    expect(saved!.map((entry) => entry.weightKg), contains(81.6));
    expect(haptics, contains(AppHaptic.success));
  });

  testWidgets("keeps to Log Weight's span: out of it, or empty, it can't "
      'be saved', (tester) async {
    await pump(tester);

    for (final typed in ['500', '12', '']) {
      await tester.enterText(find.byType(TextField), typed);
      await tester.pump();
      await tester.tap(save());
      await tester.pumpAndSettle();
    }

    final saved = await tester.runAsync(
      () => body.watchMeasurements(uid).first,
    );
    expect(saved, hasLength(1));
  });

  testWidgets('says so when the save fails', (tester) async {
    await pump(tester, hasProfile: false);

    await tester.tap(save());
    await tester.pumpAndSettle();

    expect(haptics, contains(AppHaptic.error));
    expect(find.text('Unable to Save Weight'), findsOneWidget);
  });

  testWidgets('shows nothing when signed out', (tester) async {
    when(() => appBloc.state).thenReturn(const AppUnauthenticated());
    await tester.pumpApp(const QuickWeighIn(), appBloc: appBloc);
    expect(find.byType(QuickWeighInView), findsNothing);
  });
}
