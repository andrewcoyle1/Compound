import 'package:compound/social/logic/circle_week.dart';
import 'package:compound/social/view/social_page.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  UserModel user(String id, String name) =>
      UserModel(userId: id, displayName: name, firstName: name);

  CircleStanding standing(String id, String name, int sessions) =>
      CircleStanding(
        user: user(id, name),
        sessions: sessions,
        volumeKg: 0,
        goal: 3,
      );

  Future<void> pump(WidgetTester tester, List<CircleStanding> standings) =>
      tester.pumpApp(
        SingleChildScrollView(
          child: CircleWeekHero(
            standings: standings,
            viewerId: 'me',
            onPressed: (_) {},
          ),
        ),
      );

  group(CircleWeekHero, () {
    testWidgets('shows the place, shared on a tie', (tester) async {
      await pump(tester, [
        standing('a', 'Amy', 3),
        standing('b', 'Ben', 2),
        standing('me', 'Me', 2),
        standing('c', 'Cal', 0),
      ]);

      expect(find.text('#2'), findsOneWidget);
      expect(find.text('OF 4 IN YOUR CIRCLE'), findsOneWidget);
      expect(find.text('2 of 3 this week'), findsOneWidget);
      expect(find.text('1. Amy'), findsOneWidget);
      expect(find.text('2. Ben'), findsOneWidget);
      expect(find.text('2. You'), findsOneWidget);
    });

    testWidgets('leads with the count before anyone trains', (tester) async {
      await pump(tester, [standing('me', 'Me', 0), standing('a', 'Amy', 0)]);

      expect(find.textContaining('#'), findsNothing);
      expect(find.text('0/3'), findsWidgets);
      expect(find.text('SESSIONS THIS WEEK'), findsOneWidget);
      expect(find.text("No one's trained yet this week."), findsOneWidget);
      // No place is shown that nobody earned.
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Amy'), findsOneWidget);
    });

    testWidgets('asks the reader to train once others have', (tester) async {
      await pump(tester, [standing('a', 'Amy', 1), standing('me', 'Me', 0)]);

      expect(find.text('Train to get on the board.'), findsOneWidget);
      expect(find.text('1. Amy'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
    });
  });
}
