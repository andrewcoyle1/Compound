import 'package:compound_models/compound_models.dart';

/// One row of the notifications list: a single notification, or several of
/// the same type about the same session, newest first
/// (`NotificationGroup`). Only built by [groupNotifications], so never
/// empty.
class const NotificationGroup(final List<ActivityNotificationModel> members) {
  /// The newest member, which stands for the group.
  ActivityNotificationModel get newest => members.first;

  /// The row's id: its newest member's.
  String get id => newest.id;

  /// What happened.
  ActivityType get type => newest.type;

  /// A group is unread while any member is.
  bool get isRead => members.every((member) => member.isRead);

  /// The members still unread.
  List<String> get unreadIds => [
    for (final member in members)
      if (!member.isRead) member.id,
  ];

  /// Each actor once, most recent first, so a repeat commenter is one
  /// person.
  List<ActivityNotificationModel> get actors {
    final seen = <String>{};
    return [
      for (final member in members)
        if (seen.add(member.actorId)) member,
    ];
  }

  /// Up to three avatars for the stack, most recent actor first.
  List<String?> get avatarUrls => [
    for (final actor in actors.take(3)) actor.actorImageUrl,
  ];
}

/// A notification joins a group only within this long of the group's
/// newest member.
const notificationGroupWindow = Duration(hours: 24);

/// Only session activity groups: follows, nudges, accepted requests, shares
/// and challenges are about a person or an item, and each stays a row of
/// its own.
bool isGroupable(ActivityNotificationModel notification) =>
    switch (notification.type) {
      ActivityType.like ||
      ActivityType.comment ||
      ActivityType.mention => notification.sessionId.isNotEmpty,
      _ => false,
    };

/// Groups ordered by their newest member (`NotificationGrouping.group`).
/// Same type and same session within [notificationGroupWindow] of the
/// group's newest member collapse together.
List<NotificationGroup> groupNotifications(
  Iterable<ActivityNotificationModel> notifications,
) {
  final groups = <List<ActivityNotificationModel>>[];
  // Newest first, so the last group opened for a key has the oldest
  // anchor: a notification missing its window misses every earlier one's.
  final open = <String, int>{};
  final sorted = [...notifications]
    ..sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
  for (final notification in sorted) {
    if (!isGroupable(notification)) {
      groups.add([notification]);
      continue;
    }
    final key = '${notification.type.value}|${notification.sessionId}';
    final index = open[key];
    if (index != null &&
        groups[index].first.dateCreated.difference(notification.dateCreated) <=
            notificationGroupWindow) {
      groups[index].add(notification);
    } else {
      open[key] = groups.length;
      groups.add([notification]);
    }
  }
  return [for (final members in groups) NotificationGroup(members)];
}

/// The badge: one per unread row, not per notification.
int unreadGroupCount(Iterable<ActivityNotificationModel> notifications) =>
    groupNotifications(notifications).where((group) => !group.isRead).length;
