import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/notifications/inbox/inbox_bloc.dart';
import 'package:compound/notifications/inbox/view/activity_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_repository/social_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../../../helpers/helpers.dart';

class _MockSocial extends Mock implements SocialRepository;

void main() {
  final now = DateTime(2026, 10, 15, 12);
  final viewer = sampleUser(now: now);
  late StreamController<ActivityNotificationModel> arrivals;
  late InboxBloc bloc;
  late int opened;

  ActivityNotificationModel like(String id) => ActivityNotificationModel(
    id: id,
    type: ActivityType.like,
    actorId: 'user1',
    actorName: 'Maya Chen',
    sessionId: 's1',
    sessionAuthorId: sampleUserId,
    dateCreated: now,
  );

  setUpAll(() => registerFallbackValue(viewer));

  // Built inside the test's zone, so its streams run on the fake clock.
  Future<void> pump(WidgetTester tester) async {
    final social = _MockSocial();
    arrivals = StreamController.broadcast();
    addTearDown(arrivals.close);
    when(() => social.watchIncomingFollowRequests(any()))
        .thenAnswer((_) => const Stream.empty());
    when(() => social.watchNewNotifications(sampleUserId))
        .thenAnswer((_) => arrivals.stream);
    when(() => social.notifications(sampleUserId)).thenAnswer((_) async => []);
    bloc = InboxBloc(social: social, analytics: const AnalyticsRepository());
    opened = 0;
    await tester.pumpApp(
      ActivityBannerOverlay(onOpen: () => opened++, child: const Text('Today')),
      inboxBloc: bloc,
    );
    bloc.add(InboxViewerChanged(viewer));
    await tester.pump();
  }

  Future<void> arrive(WidgetTester tester, String id) async {
    arrivals.add(like(id));
    await tester.pump();
    // In, as it fades in (350 ms of the 4 s).
    await tester.pumpAndSettle();
  }

  group(ActivityBannerOverlay, () {
    testWidgets('shows an arrival over the app, then goes after 4 s', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const Key('ActivityBanner')), findsNothing);
      await arrive(tester, 'a');
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Maya Chen liked your workout'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Maya Chen liked your workout'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Maya Chen liked your workout'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Maya Chen liked your workout'), findsNothing);
      expect(bloc.state.banner, isNull);
    });

    testWidgets('a tap opens the inbox and puts it away', (tester) async {
      await pump(tester);
      await arrive(tester, 'a');
      await tester.tap(find.byKey(const Key('ActivityBanner')));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.byKey(const Key('ActivityBanner')), findsNothing);
    });

    testWidgets('a flick up puts it away', (tester) async {
      await pump(tester);
      await arrive(tester, 'a');
      await tester.fling(
        find.byKey(const Key('ActivityBanner')),
        const Offset(0, -100),
        1000,
      );
      await tester.pumpAndSettle();
      expect(opened, 0);
      expect(find.byKey(const Key('ActivityBanner')), findsNothing);
    });

    testWidgets('a newer arrival takes the banner and its own 4 s', (
      tester,
    ) async {
      await pump(tester);
      await arrive(tester, 'a');
      await tester.pump(const Duration(seconds: 3));
      await arrive(tester, 'b');
      await tester.pump(const Duration(seconds: 2));
      expect(bloc.state.banner?.id, 'b');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(bloc.state.banner, isNull);
    });
  });
}
