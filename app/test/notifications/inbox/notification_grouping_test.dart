import 'dart:ui';

import 'package:compound/l10n/l10n.dart';
import 'package:compound/notifications/inbox/notification_grouping.dart';
import 'package:compound/notifications/inbox/view/notification_titles.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `NotificationGroupingTests`: same type and session within 24
/// hours of the group's newest member collapse into one row.
void main() {
  final now = DateTime.utc(2026, 10, 15, 12);
  final l10n = lookupAppLocalizations(const Locale('en'));

  ActivityNotificationModel item(
    String id, {
    ActivityType type = ActivityType.like,
    String? actor,
    String session = 's1',
    double hoursAgo = 0,
    bool isRead = false,
    String? text,
  }) => ActivityNotificationModel(
    id: id,
    type: type,
    actorId: actor ?? 'actor-$id',
    actorName: actor ?? 'Actor $id',
    actorImageUrl: 'url-${actor ?? id}',
    sessionId: type == ActivityType.follow || type == ActivityType.nudge
        ? ''
        : session,
    sessionAuthorId: 'me',
    commentText: text,
    dateCreated: now.subtract(Duration(minutes: (hoursAgo * 60).round())),
    isRead: isRead,
  );

  List<List<String>> ids(List<NotificationGroup> groups) => [
    for (final group in groups) [for (final member in group.members) member.id],
  ];

  test('likes on one session within a day collapse', () {
    final groups = groupNotifications([
      item('a', hoursAgo: 23),
      item('b'),
      item('c', hoursAgo: 2),
    ]);
    expect(ids(groups), [
      ['b', 'c', 'a'],
    ]);
  });

  test('the window is measured from the newest member', () {
    // 12-hour steps would chain forever; anchoring on the newest cuts at 24.
    final groups = groupNotifications([
      item('a'),
      item('b', hoursAgo: 12),
      item('c', hoursAgo: 24.5),
      item('d', hoursAgo: 36),
    ]);
    expect(ids(groups), [
      ['a', 'b'],
      ['c', 'd'],
    ]);
  });

  test('groups are ordered by their newest member', () {
    final groups = groupNotifications([
      item('old-s2', session: 's2', hoursAgo: 5),
      item('s1-a', hoursAgo: 3),
      item('new-s2', session: 's2', hoursAgo: 1),
      item('s1-b', hoursAgo: 4),
    ]);
    expect(ids(groups), [
      ['new-s2', 'old-s2'],
      ['s1-a', 's1-b'],
    ]);
  });

  test('mixed types and sessions do not merge', () {
    final groups = groupNotifications([
      item('like'),
      item('comment', type: ActivityType.comment, hoursAgo: 1),
      item('other', session: 's2', hoursAgo: 2),
    ]);
    expect(groups, hasLength(3));
  });

  test('follows and nudges never group', () {
    final groups = groupNotifications([
      item('f1', type: ActivityType.follow),
      item('f2', type: ActivityType.follow, hoursAgo: 1),
      item('n1', type: ActivityType.nudge),
      item('n2', type: ActivityType.nudge, hoursAgo: 1),
    ]);
    expect(groups, hasLength(4));
    expect(groups.every((group) => group.members.length == 1), isTrue);
  });

  test('the title names the newest actor and counts the rest', () {
    final four = groupNotifications([
      for (final (index, name) in ['Alice', 'Bob', 'Cara', 'Dan'].indexed)
        item(name, actor: name, hoursAgo: index.toDouble()),
    ]);
    expect(
      notificationGroupTitle(l10n, four.first),
      'Alice and 3 others liked your workout',
    );
    expect(four.first.avatarUrls, ['url-Alice', 'url-Bob', 'url-Cara']);

    final two = groupNotifications([
      item('a', type: ActivityType.comment, actor: 'Alice'),
      item('b', type: ActivityType.comment, actor: 'Bob', hoursAgo: 1),
    ]);
    expect(
      notificationGroupTitle(l10n, two.first),
      'Alice and Bob commented on your workout',
    );

    // One person commenting twice is one actor, not "and 1 others".
    final repeat = groupNotifications([
      item('a', type: ActivityType.comment, actor: 'Alice'),
      item('b', type: ActivityType.comment, actor: 'Alice', hoursAgo: 1),
    ]);
    expect(
      notificationGroupTitle(l10n, repeat.first),
      'Alice commented on your workout',
    );

    final mentions = groupNotifications([
      item('a', type: ActivityType.mention, actor: 'Alice'),
      item('b', type: ActivityType.mention, actor: 'Bob', hoursAgo: 1),
    ]);
    expect(
      notificationGroupTitle(l10n, mentions.first),
      'Alice and Bob mentioned you',
    );

    // A single notification keeps its own title.
    expect(
      notificationGroupTitle(l10n, groupNotifications([item('solo')]).first),
      'Actor solo liked your workout',
    );
  });

  test('the badge counts unread groups, not rows', () {
    final notifications = [
      item('a'),
      item('b', hoursAgo: 1),
      item('c', hoursAgo: 2, isRead: true),
      item('read', session: 's2', hoursAgo: 1, isRead: true),
      item('follow', type: ActivityType.follow),
    ];
    expect(unreadGroupCount(notifications), 2);
  });

  test('a group is unread while any member is', () {
    final group = groupNotifications([
      item('a', isRead: true),
      item('b', hoursAgo: 1),
    ]).single;
    expect(group.isRead, isFalse);
    expect(group.unreadIds, ['b']);
    expect(group.id, 'a');
  });

  test('a session notification without a session stands alone', () {
    final groups = groupNotifications([
      item('a', session: ''),
      item('b', session: '', hoursAgo: 1),
    ]);
    expect(groups, hasLength(2));
  });

  group('a single notification’s title', () {
    String title(ActivityNotificationModel notification) =>
        notificationTitle(l10n, notification);

    test('says what happened', () {
      expect(title(item('x', actor: 'Maya')), 'Maya liked your workout');
      expect(
        title(item('x', type: ActivityType.follow, actor: 'Maya')),
        'Maya started following you',
      );
      expect(
        title(item('x', type: ActivityType.nudge, actor: 'Maya')),
        'Maya nudged you to train',
      );
      expect(
        title(item('x', type: ActivityType.followAccepted, actor: 'Maya')),
        'Maya accepted your follow request',
      );
    });

    test('quotes the start of a comment or mention', () {
      expect(
        title(item('x', type: ActivityType.comment, actor: 'Maya')),
        'Maya commented',
      );
      expect(
        title(
          item('x', type: ActivityType.comment, actor: 'Maya', text: 'Nice'),
        ),
        'Maya commented: "Nice"',
      );
      expect(
        title(item('x', type: ActivityType.mention, actor: 'Maya')),
        'Maya mentioned you',
      );
      expect(
        title(
          item('x', type: ActivityType.mention, actor: 'Maya', text: 'a' * 80),
        ),
        'Maya mentioned you: "${'a' * 60}"',
      );
    });

    test('names a share or challenge when it can', () {
      expect(
        title(item('x', type: ActivityType.share, actor: 'Maya')),
        'Maya shared a workout',
      );
      expect(
        title(
          item('x', type: ActivityType.share, actor: 'Maya', text: 'Push Day'),
        ),
        'Maya shared Push Day',
      );
      expect(
        title(item('x', type: ActivityType.challengeComplete)),
        'You finished a challenge',
      );
      expect(
        title(
          item('x', type: ActivityType.challengeComplete, text: 'October 20'),
        ),
        'You finished October 20',
      );
    });
  });
}
