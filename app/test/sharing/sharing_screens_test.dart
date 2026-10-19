import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/notifications/inbox/inbox_bloc.dart';
import 'package:compound/notifications/inbox/view/notifications_page.dart';
import 'package:compound/sharing/sharing_routes.dart';
import 'package:compound/sharing/view/share_to_follower_page.dart';
import 'package:compound/sharing/view/shared_item_page.dart';
import 'package:compound/social/social.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_repository/social_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../helpers/helpers.dart';

/// Sharing over the staging world: a template to a mutual, the shared item
/// from the inbox, and the workout card.
void main() {
  late SocialWorld world;
  late InMemoryTrainingLibraryRepository library;
  late ShareRecorder shares;
  late AnalyticsRecorder analytics;
  final template = PrebuiltCatalogue.instance.workoutTemplates.first;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> pump(WidgetTester tester, String location) async {
    analytics = AnalyticsRecorder();
    world = (await tester.runAsync(
      () => SocialWorld.create(analytics: analytics),
    ))!;
    library = InMemoryTrainingLibraryRepository();
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
      trainingLibraryRepository: library,
      socialRepository: world.social,
      circleBloc: world.circle,
      inboxBloc: InboxBloc(social: world.social, analytics: analytics)
        ..add(InboxViewerChanged(world.viewer)),
      shareSheet: shares,
      router: GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/host',
            builder: (context, _) => Center(
              child: TextButton(
                onPressed: () => unawaited(
                  showShareToFollower(context, TemplateSharePayload(template)),
                ),
                child: const Text('Host'),
              ),
            ),
          ),
          GoRoute(
            path: '/social',
            builder: (_, _) => const SocialPage(),
            routes: [
              GoRoute(
                path: NotificationsPage.path,
                name: NotificationsPage.name,
                builder: (_, _) => const NotificationsPage(),
              ),
            ],
          ),
          ...socialRoutes,
          ...sharingRoutes,
        ],
      ),
    );
    await settle(tester);
  }

  testWidgets('shares a template with a mutual', (tester) async {
    await pump(tester, '/host');
    await tester.tap(find.text('Host'));
    await settle(tester);
    expect(find.text('Share ${template.name}'), findsOneWidget);
    expect(find.text('Maya Chen'), findsOneWidget);

    await tester.tap(find.text('Maya Chen'));
    await tester.pump();
    await tester.tap(find.text('Send'));
    await settle(tester);
    expect(find.text('Share ${template.name}'), findsNothing);
    final sent = (await tester.runAsync(
      () => world.social.notifications('user1'),
    ))!;
    expect(
      sent.where((n) => n.type == ActivityType.share).single.commentText,
      template.name,
    );
    expect(analytics.names, contains('ShareToFollowerView_Send_Success'));
  });

  testWidgets('the inbox opens the shared item, which adds it to the '
      'library', (tester) async {
    await pump(tester, '/social/notifications');
    tester.view.physicalSize = const Size(1200, 4000);
    addTearDown(tester.view.reset);
    await tester.pump();
    await tester.tap(
      find.textContaining('Maya Chen shared', findRichText: true).first,
    );
    await settle(tester);
    expect(find.byType(SharedItemPage), findsOneWidget);
    expect(find.text('Maya Chen shared this with you.'), findsOneWidget);
    expect(find.text(template.name), findsWidgets);

    await tester.tap(find.text('Add to Library'));
    await settle(tester);
    expect(find.byType(SharedItemPage), findsNothing);
    final saved = (await tester.runAsync(
      () => library.watchUserWorkoutTemplates(sampleUserId).first,
    ))!;
    expect(saved.single.name, template.name);
    expect(
      (await tester.runAsync(
        () => world.social.share('sample-share-template'),
      ))!.status,
      ShareStatus.accepted,
    );
  });

  testWidgets('a shared item opened by id; declining closes it', (
    tester,
  ) async {
    await pump(tester, '/social');
    unawaited(
      GoRouter.of(tester.element(find.byType(SocialPage)))
          .push('/shares/sample-share-template'),
    );
    await settle(tester);
    expect(find.text('Add to Library'), findsOneWidget);
    expect(find.textContaining('shared this with you'), findsNothing);
    await tester.tap(find.text('Decline'));
    await settle(tester);
    expect(find.byType(SharedItemPage), findsNothing);
    expect(
      (await tester.runAsync(
        () => world.social.share('sample-share-template'),
      ))!.status,
      ShareStatus.dismissed,
    );
  });

  testWidgets('a shared item that cannot be read says so', (tester) async {
    await pump(tester, '/shares/missing');
    expect(find.text('This shared item is no longer available.'), findsOne);
  });

  testWidgets('a feed card shares its workout as an image', (tester) async {
    await pump(tester, '/social');
    final more = find.bySemanticsLabel('More actions');
    await reveal(tester, more);
    await tester.tap(more.first);
    await settle(tester);
    await tester.tap(find.text('Share Image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Square'));
    await settle(tester);
    expect(shares.images.single.$1, 'compound-workout.png');
    expect(analytics.names, contains('WorkoutSessionRow_ShareImage_Success'));
  });

  testWidgets("a workout's detail shares it as an image", (tester) async {
    await pump(tester, '/social');
    final session = world.circle.state.feed.first;
    unawaited(
      GoRouter.of(tester.element(find.byType(SocialPage)))
          .push('/sessions/${session.authorId}/${session.id}', extra: session),
    );
    await settle(tester);
    expect(find.byType(WorkoutSessionDetailPage), findsOneWidget);
    await tester.tap(find.byTooltip('Share Image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Story'));
    await settle(tester);
    expect(shares.images, hasLength(1));
  });
}
