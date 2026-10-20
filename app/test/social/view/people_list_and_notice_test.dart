import 'package:app_ui/app_ui.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/followers/people_list_page.dart';
import 'package:compound/social/view/circle_notice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  testWidgets('removes a follower after asking', (tester) async {
    final world = (await tester.runAsync(SocialWorld.create))!;
    final followers = (await tester.runAsync(
      () => world.social.followersOf(sampleUserId, viewer: world.viewer),
    ))!;
    await tester.pumpApp(
      PeopleListPage(
        request: PeopleListRequest(
          kind: PeopleListKind.followers,
          people: followers,
          canRemove: true,
        ),
      ),
      userRepository: world.users,
      workoutSessionRepository: world.sessions,
      socialRepository: world.social,
      circleBloc: world.circle,
    );
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Charlie Nguyen'), findsOneWidget);

    final before = find.byTooltip('Remove').evaluate().length;
    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    expect(find.text('Remove Follower?'), findsOneWidget);
    await tester.tap(find.text('Remove').last);
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    expect(find.byTooltip('Remove'), findsNWidgets(before - 1));
  });

  testWidgets('an empty list says so', (tester) async {
    await tester.pumpApp(
      const PeopleListPage(
        request: PeopleListRequest(kind: PeopleListKind.following, people: []),
      ),
    );
    expect(find.text('No Followers Yet'), findsOneWidget);
  });

  testWidgets('a failed follow or nudge shows a snack bar', (tester) async {
    late BuildContext context;
    await tester.pumpApp(
      Scaffold(
        body: Builder(
          builder: (inner) {
            context = inner;
            return const SizedBox();
          },
        ),
      ),
    );
    for (final (notice, text) in [
      (CircleNotice.followFailed, 'Unable to follow user'),
      (CircleNotice.unfollowFailed, 'Unable to unfollow user'),
      (CircleNotice.cancelRequestFailed, 'Unable to cancel request'),
      (CircleNotice.nudgeFailed, 'Unable to nudge Dev'),
    ]) {
      showCircleNotice(
        context,
        CircleState(notice: notice, noticeName: 'Dev', noticeId: 1),
      );
      await tester.pump();
      expect(find.textContaining(text), findsOneWidget);
    }
    showCircleNotice(context, const CircleState());
  });
}
