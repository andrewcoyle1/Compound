import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_repository/social_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// The staging flavor's social world, for widget tests: the sample user,
/// their sessions, and the in-memory Firestore around them, with a circle
/// that has loaded.
final class SocialWorld {
  new _(this.now, this.users, this.sessions, this.social, this.circle);

  static Future<SocialWorld> create({
    DateTime? now,
    AnalyticsRepository analytics = const AnalyticsRepository(),
  }) async {
    final at = now ?? DateTime.now();
    final users = InMemoryUserRepository(
      users: {sampleUserId: sampleUser(now: at)},
    );
    final sessions = InMemoryWorkoutSessionRepository(
      sessions: sampleWorkoutSessions(uid: sampleUserId, now: at),
    );
    final social = await inMemorySocialRepository(
      firestore: FakeFirebaseFirestore(),
      users: users,
      now: at,
    );
    final circle = CircleBloc(
      social: social,
      sessions: sessions,
      analytics: analytics,
    )..add(CircleViewerChanged(sampleUser(now: at)));
    await circle.stream.firstWhere(
      (state) =>
          state.hasLoadedFollowingSessions &&
          state.followingUsers.isNotEmpty &&
          state.ownSessions.isNotEmpty,
    );
    return SocialWorld._(at, users, sessions, social, circle);
  }

  final DateTime now;
  final InMemoryUserRepository users;
  final InMemoryWorkoutSessionRepository sessions;
  final SocialRepository social;
  final CircleBloc circle;

  UserModel get viewer => circle.state.viewer!;
}

/// Scrolls the Social dashboard until [finder] is on screen. Its banners
/// vary by day (the week's recap shows on the week's first day), so a test
/// scrolls to what it needs rather than assume where it sits.
Future<void> revealOnDashboard(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
    await tester.drag(
      find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
      const Offset(0, -200),
    );
    await tester.pump();
  }
  await tester.ensureVisible(finder.first);
  await tester.pump();
}
