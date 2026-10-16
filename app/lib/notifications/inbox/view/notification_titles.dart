import 'package:compound/l10n/l10n.dart';
import 'package:compound/notifications/inbox/notification_grouping.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// A row's title: the grouped one once several notifications share the
/// row, otherwise its own (`NotificationGroup.groupedTitle`,
/// `NotificationsView.activityNotificationTitle`).
String notificationGroupTitle(AppLocalizations l10n, NotificationGroup group) {
  if (group.members.length == 1) return notificationTitle(l10n, group.newest);
  final actors = actorSummary(l10n, group);
  return switch (group.type) {
    ActivityType.comment => l10n.inboxGroupCommented(actors),
    ActivityType.mention => l10n.inboxGroupMentioned(actors),
    _ => l10n.inboxGroupLiked(actors),
  };
}

/// "Alice", "Alice and Bob", "Alice and 3 others".
String actorSummary(AppLocalizations l10n, NotificationGroup group) {
  final actors = group.actors;
  return switch (actors.length) {
    0 || 1 => group.newest.actorName,
    2 => l10n.inboxActorsTwo(actors[0].actorName, actors[1].actorName),
    _ => l10n.inboxActorsMany(actors[0].actorName, '${actors.length - 1}'),
  };
}

/// One notification's title.
String notificationTitle(
  AppLocalizations l10n,
  ActivityNotificationModel notification,
) {
  final name = notification.actorName;
  final text = notification.commentText;
  // A comment's first 60 characters.
  final preview = text?.characters.take(60).toString();
  return switch (notification.type) {
    ActivityType.like => l10n.inboxLiked(name),
    ActivityType.comment =>
      preview == null
          ? l10n.inboxCommented(name)
          : l10n.inboxCommentedText(name, preview),
    ActivityType.mention =>
      preview == null
          ? l10n.inboxMentioned(name)
          : l10n.inboxMentionedText(name, preview),
    ActivityType.follow => l10n.inboxFollowed(name),
    ActivityType.nudge => l10n.inboxNudged(name),
    ActivityType.followAccepted => l10n.inboxFollowAccepted(name),
    ActivityType.share =>
      text == null
          ? l10n.inboxSharedWorkout(name)
          : l10n.inboxShared(name, text),
    ActivityType.challengeComplete =>
      text == null
          ? l10n.inboxChallengeDone
          : l10n.inboxChallengeDoneNamed(text),
  };
}
