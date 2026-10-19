import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/sharing/session_web_link.dart';
import 'package:compound/social/feed/feed_session_card.dart';
import 'package:compound/social/social.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:social_repository/social_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../helpers/helpers.dart';

/// Workouts' web pages (`SessionWebLink`): the feed card's Share, the
/// detail's Copy Link, and a page's link opening the workout in the app,
/// all on the staging world.
void main() {
  final links = SessionWebLink(Uri.parse('https://compound.test/s'));
  final now = DateTime.now();
  final own = sampleWorkoutSessions(uid: sampleUserId, now: now);
  final pushA = own.firstWhere((s) => s.id == 'sample-session-push-a');
  final author = sampleUser(now: now);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  group(SessionWebLink, () {
    test("is the author's and the workout's ids under the base", () {
      expect(
        links.url(pushA, author: author),
        Uri.parse('https://compound.test/s/$sampleUserId/${pushA.id}'),
      );
    });

    test('is absent where the page would answer 404', () {
      expect(links.url(pushA, author: null), isNull);
      expect(
        links.url(
          pushA,
          author: UserModel.fromFirestore({
            ...author.toFirestore(),
            UserModelKeys.isPrivate: true,
          }),
        ),
        isNull,
      );
      final unfinished = WorkoutSessionModel.fromFirestore({
        ...pushA.toFirestore(),
        WorkoutSessionModelKeys.endedAt: null,
      });
      expect(links.url(unfinished, author: author), isNull);
      final deleted = WorkoutSessionModel.fromFirestore({
        ...pushA.toFirestore(),
        WorkoutSessionModelKeys.deletedAt: now,
      });
      expect(links.url(deleted, author: author), isNull);
      final hidden = WorkoutSessionModel.fromFirestore({
        ...pushA.toFirestore(),
        WorkoutSessionModelKeys.hidden: true,
      });
      expect(links.url(hidden, author: author), isNull);
    });

    test('reads a page of its own host back as the workout', () {
      expect(
        links.parse(Uri.parse('https://Compound.test/s/user1/abc/')),
        const SessionLink(id: 'abc', authorId: 'user1'),
      );
      expect(links.parse(links.url(pushA, author: author)!), isNotNull);
      for (final other in [
        'http://compound.test/s/user1/abc',
        'https://example.com/s/user1/abc',
        'https://compound.test/x/user1/abc',
        'https://compound.test/s/user1',
        'https://compound.test/s/user1/abc/more',
        'compound://tab/social',
      ]) {
        expect(links.parse(Uri.parse(other)), isNull, reason: other);
      }
    });
  });

  group('shareWorkoutSummary', () {
    test('names the workout, its exercises, sets and volume', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        shareWorkoutSummary(l10n, pushA, locale: 'en'),
        matches(
          RegExp(
            r'^Push A · \d+ exercises · \d+ sets · [\d,.]+ (kg|lb) lifted$',
          ),
        ),
      );
      final rest = own.firstWhere((s) => s.isRestDay);
      expect(
        shareWorkoutSummary(l10n, rest, locale: 'en'),
        '${rest.name} · 0 exercises · 0 sets',
      );
    });
  });

  group('in the social screens', () {
    late SocialWorld world;
    late AnalyticsRecorder analytics;
    late ShareRecorder shares;

    Future<void> pump(
      WidgetTester tester,
      String Function(SocialWorld world) location, {
      bool withLinks = true,
    }) async {
      world = (await tester.runAsync(SocialWorld.create))!;
      analytics = AnalyticsRecorder();
      shares = ShareRecorder();
      final appBloc = MockAppBloc();
      when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => appBloc.state).thenReturn(
        AppAuthenticated(
          const AuthUser(uid: sampleUserId, isAnonymous: false),
          profile: world.viewer,
          profileStatus: AppProfileStatus.ready,
        ),
      );
      await tester.pumpApp(
        const SizedBox(),
        appBloc: appBloc,
        analyticsRepository: analytics,
        userRepository: world.users,
        workoutSessionRepository: world.sessions,
        socialRepository: world.social,
        circleBloc: world.circle,
        shareSheet: shares,
        sessionWebLink: withLinks ? links : null,
        router: GoRouter(
          initialLocation: location(world),
          routes: [
            GoRoute(path: '/social', builder: (_, _) => const SocialPage()),
            ...socialRoutes,
          ],
        ),
      );
      await settle(tester);
    }

    Future<WorkoutSessionModel> shareFirstCard(WidgetTester tester) async {
      await tester.tap(find.text('Activities'));
      await tester.pump();
      final card = find.byType(FeedSessionCard).first;
      await tester.scrollUntilVisible(
        card,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final share = find.descendant(
        of: card,
        matching: find.bySemanticsLabel('Share workout'),
      );
      await tester.ensureVisible(share);
      await tester.pump();
      await tester.tap(share);
      await settle(tester);
      return tester.widget<FeedSessionCard>(card).entry.session;
    }

    // WorkoutSessionRowView's ShareLink(item: link, message: summary).
    testWidgets("a feed card shares its summary and the workout's page", (
      tester,
    ) async {
      await pump(tester, (_) => '/people/user1');
      final session = await shareFirstCard(tester);
      expect(
        shares.texts.single,
        matches(
          RegExp(
            '^${RegExp.escape(session.name)} · .+ sets.*\n'
            '${RegExp.escape('https://compound.test/s/user1/${session.id}')}\$',
          ),
        ),
      );
    });

    testWidgets('without a page, a feed card shares the summary alone', (
      tester,
    ) async {
      await pump(tester, (_) => '/people/user1', withLinks: false);
      final session = await shareFirstCard(tester);
      expect(shares.texts.single, startsWith(session.name));
      expect(shares.texts.single, isNot(contains('\n')));
    });

    // WorkoutSessionDetailPresenter.onCopyLinkPressed; opened by its ids
    // alone, as a link opens it, so the workout is read by its author.
    testWidgets("Copy Link puts someone's workout's page on the clipboard", (
      tester,
    ) async {
      final copied = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') copied.add(call.arguments);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      late WorkoutSessionModel maya;
      await pump(tester, (world) {
        maya = world.circle.state.sessions.firstWhere(
          (s) => s.authorId == 'user1',
        );
        return '/sessions/user1/${maya.id}';
      });
      expect(find.text(maya.name), findsWidgets);

      await tester.tap(find.byTooltip('Share Image'));
      await tester.pumpAndSettle();
      expect(find.text('Story'), findsOneWidget);
      await tester.tap(find.text('Copy Link'));
      await settle(tester);

      final link = 'https://compound.test/s/user1/${maya.id}';
      expect(copied, [
        {'text': link},
      ]);
      expect(analytics.parameters('WorkoutSessionDetailView_CopyLink'), {
        'session_id': maya.id,
      });
    });

    testWidgets('Copy Link is not offered without a page', (tester) async {
      await pump(
        tester,
        (_) => '/sessions/$sampleUserId/sample-session-push-a',
        withLinks: false,
      );
      expect(find.text('Push A'), findsWidgets);
      await tester.tap(find.byTooltip('Share Image'));
      await tester.pumpAndSettle();
      expect(find.text('Story'), findsOneWidget);
      expect(find.text('Copy Link'), findsNothing);
    });
  });

  // A page's link, opened from outside, lands where Swift's
  // `DeepLink.session` does: someone's workout over Social, the user's own
  // in their history.
  group('a workout page link', () {
    late SocialRepository social;

    Future<void> pump(WidgetTester tester) async {
      final users = InMemoryUserRepository(
        users: {sampleUserId: sampleUser(now: now)},
        settings: {sampleUserId: sampleUserSettings(now: now)},
      );
      social = (await tester.runAsync(
        () => inMemorySocialRepository(
          firestore: FakeFirebaseFirestore(),
          users: users,
          now: now,
        ),
      ))!;
      await tester.pumpWidget(
        App(
          coachRepository: silentCoachRepository(),
          purchasesRepository: FakePurchasesRepository(),
          programRepository: InMemoryProgramRepository(),
          trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
          authRepository: InMemoryAuthRepository(
            user: InMemoryAuthRepository.sampleUser,
          ),
          userRepository: users,
          workoutSessionRepository: InMemoryWorkoutSessionRepository(
            sessions: own,
          ),
          nutritionRepository: InMemoryNutritionRepository(),
          bodyRepository: InMemoryBodyRepository(),
          socialRepository: social,
          sessionWebLink: links,
        ),
      );
      await settle(tester);
    }

    Future<void> open(WidgetTester tester, String url) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(
          MethodCall('pushRouteInformation', {'location': url}),
        ),
        (_) {},
      );
      await settle(tester);
    }

    testWidgets("opens someone's workout over Social", (tester) async {
      await pump(tester);
      final maya = (await tester.runAsync(
        () => social.sessionsByAuthor('user1'),
      ))!.firstWhere((s) => s.endedAt != null && !s.isRestDay);
      await open(tester, 'https://compound.test/s/user1/${maya.id}');
      expect(find.byType(WorkoutSessionDetailPage), findsOneWidget);
      expect(find.text(maya.name), findsWidgets);

      await tester.pageBack();
      await settle(tester);
      expect(find.byType(WorkoutSessionDetailPage), findsNothing);
      expect(find.byType(SocialPage), findsOneWidget);
    });

    testWidgets("opens the user's own workout in their history", (
      tester,
    ) async {
      await pump(tester);
      await open(tester, 'https://compound.test/s/$sampleUserId/${pushA.id}');
      expect(find.byType(WorkoutSessionDetailPage), findsOneWidget);
      expect(find.text('Push A'), findsWidgets);
    });

    testWidgets("ignores another host's page", (tester) async {
      await pump(tester);
      await open(tester, 'https://example.com/s/user1/abc');
      expect(find.byType(WorkoutSessionDetailPage), findsNothing);
    });
  });
}
