import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';

DeepLink? _url(String url) => DeepLink.parse(Uri.parse(url));

void main() {
  group(DeepLinkTab, () {
    // AppShellPresenterTests.testRetiredTabNamesStillLand
    test('retired tab names still land', () {
      expect(DeepLinkTab.fromName('dashboard'), DeepLinkTab.today);
      expect(DeepLinkTab.fromName('search'), DeepLinkTab.today);
      expect(DeepLinkTab.fromName('add'), DeepLinkTab.today);
      expect(DeepLinkTab.fromName('analytics'), DeepLinkTab.progress);
    });

    test('every tab is found by its own name, and paths match the router', () {
      for (final tab in DeepLinkTab.values) {
        expect(DeepLinkTab.fromName(tab.name), tab);
      }
      expect(DeepLinkTab.values.map((t) => t.path), [
        '/today',
        '/training',
        '/nutrition',
        '/progress',
        '/social',
      ]);
      expect(DeepLinkTab.fromName('sleep'), isNull);
    });
  });

  group('DeepLink.parse', () {
    test('reads a tab from the path or the query', () {
      expect(
        _url('compound://tab/nutrition'),
        const TabLink(DeepLinkTab.nutrition),
      );
      expect(
        _url('compound://TAB/Progress/'),
        const TabLink(DeepLinkTab.progress),
      );
      expect(
        _url('compound://tab?name=social'),
        const TabLink(DeepLinkTab.social),
      );
      expect(
        _url('compound://tab?Tab=Training'),
        const TabLink(DeepLinkTab.training),
      );
      expect(
        _url('compound://tab/dashboard'),
        const TabLink(DeepLinkTab.today),
      );
    });

    test('an unrecognised link goes nowhere', () {
      expect(_url('compound://tab/sleep'), isNull);
      expect(_url('compound://tab'), isNull);
      expect(_url('compound://settings/units'), isNull);
    });

    // InviteDeepLinkTests
    test('join links carry the normalised code', () {
      expect(_url('compound://join/PUSH2345'), const JoinLink('PUSH2345'));
      expect(_url('compound://join/push2345'), const JoinLink('PUSH2345'));
      expect(_url('compound://JOIN/PUSH2345/'), const JoinLink('PUSH2345'));
      expect(_url('compound://join/push-2345'), const JoinLink('PUSH2345'));
    });

    test('a join link without a valid code goes nowhere', () {
      expect(_url('compound://join'), isNull);
      expect(_url('compound://join/SHORT'), isNull);
      expect(_url('compound://join/PUSH2340'), isNull);
    });

    // WidgetSnapshotTests: the widget's link
    test('the workout widget link', () {
      expect(_url('compound://workout'), const WorkoutLink());
    });

    test('the Browse Recipes shortcut', () {
      expect(_url('compound://recipes'), const RecipesLink());
      expect(const RecipesLink().props, isEmpty);
    });
  });

  group('DeepLink.fromData', () {
    test('reads deep_link as a full URL', () {
      expect(
        DeepLink.fromData(const {'deep_link': 'compound://join/PUSH2345'}),
        const JoinLink('PUSH2345'),
      );
      expect(
        DeepLink.fromData(const {
          'deep_link': 'compound://tab/progress',
          'tab': 'social',
        }),
        const TabLink(DeepLinkTab.progress),
      );
    });

    test('an unparseable deep_link falls through to the other keys', () {
      expect(
        DeepLink.fromData(const {'deep_link': '::not a url', 'tab': 'social'}),
        const TabLink(DeepLinkTab.social),
      );
    });

    // AppShellPresenterTests.testASessionPushParsesItsFieldsAndSelectsSocial
    test('a session push parses its fields', () {
      expect(
        DeepLink.fromData(const {
          'tab': 'dashboard',
          'type': 'mention',
          'session_id': 's1',
          'session_author_id': 'u1',
          'actor_id': 'a1',
        }),
        const SessionLink(id: 's1', authorId: 'u1', openComments: true),
      );
      expect(
        DeepLink.fromData(const {
          'type': 'comment',
          'session_id': 's1',
          'session_author_id': 'u1',
        }),
        const SessionLink(id: 's1', authorId: 'u1', openComments: true),
      );
      expect(
        DeepLink.fromData(const {
          'type': 'like',
          'session_id': 's1',
          'session_author_id': 'u1',
        }),
        const SessionLink(id: 's1', authorId: 'u1'),
      );
      // A follow has no session, so it is just the tab it names.
      expect(
        DeepLink.fromData(const {
          'tab': 'social',
          'type': 'follow',
          'session_id': '',
          'session_author_id': '',
        }),
        const TabLink(DeepLinkTab.social),
      );
      expect(
        DeepLink.fromData(const {'session_id': 's1', 'session_author_id': ''}),
        isNull,
      );
    });

    // AppShellPresenterTests.testAFollowRequestPushOpensNotificationsFromSocial
    test('a follow request opens notifications, even with a tab', () {
      expect(
        DeepLink.fromData(const {
          'tab': 'dashboard',
          'type': 'follow_request',
          'session_id': '',
          'session_author_id': '',
          'actor_id': 'a1',
        }),
        const NotificationsLink(),
      );
    });

    test('the server pushes land where Swift sends them', () {
      // buildStreakReminderPush and buildWeeklyDigestPush in functions/lib.js
      expect(
        DeepLink.fromData(const {'tab': 'training', 'type': 'streakReminder'}),
        const TabLink(DeepLinkTab.training),
      );
      expect(
        DeepLink.fromData(const {'tab': 'social', 'type': 'weeklyDigest'}),
        const TabLink(DeepLinkTab.social),
      );
      expect(
        DeepLink.fromData(const {'tab': 'Nutrition'}),
        const TabLink(DeepLinkTab.nutrition),
      );
    });

    // AppShellPresenterTests.testAPushWithNoDestinationIsIgnored
    test('a payload with no destination is null', () {
      expect(DeepLink.fromData(const {'body': 'hello'}), isNull);
      expect(DeepLink.fromData(const {'tab': 'sleep'}), isNull);
      expect(DeepLink.fromData(const {'tab': 3}), isNull);
    });
  });

  test('links without fields are equal by type', () {
    expect(const NotificationsLink().props, isEmpty);
    expect(const WorkoutLink().props, isEmpty);
    expect(const NotificationsLink(), isNot(const WorkoutLink()));
  });

  group('toLocation', () {
    test('maps each link to a router path', () {
      expect(const TabLink(DeepLinkTab.progress).toLocation(), '/progress');
      expect(const NotificationsLink().toLocation(), '/social/notifications');
      expect(const JoinLink('PUSH2345').toLocation(), '/social');
      expect(const WorkoutLink().toLocation(), '/today');
      expect(const RecipesLink().toLocation(), '/nutrition/recipes');
    });

    test(
      "the user's own session opens in history, anyone else's on Social",
      () {
        const link = SessionLink(id: 's1', authorId: 'me');
        expect(link.toLocation(currentUserId: 'me'), '/training/history/s1');
        expect(link.toLocation(currentUserId: 'you'), '/social');
        expect(link.toLocation(), '/social');
      },
    );
  });
}
