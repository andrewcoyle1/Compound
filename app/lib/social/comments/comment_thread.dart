import 'package:compound/social/logic/people.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';

/// Someone who can be picked from the mention row
/// (`CommentMentionCandidate`). The inserted text is `@handle`, or
/// `@FirstName` for someone without one; the id is what the comment records.
final class const MentionCandidate({
  required final String id,
  required final String fullName,
  final String? username,
}) extends Equatable {
  /// The first word of [fullName].
  String get firstName => fullName.split(' ').first;

  /// What follows the `@` in the draft.
  String get mentionText => username ?? firstName;

  /// The suggestion's title.
  String get label => username == null ? fullName : '@$username';

  @override
  List<Object?> get props => [id, fullName, username];
}

/// The rules a comment thread follows (`CommentsPresenter`): its order, who
/// is hidden, and mentions.
abstract final class CommentThread {
  /// Top-level comments oldest first, each followed by its replies oldest
  /// first. A reply whose parent is gone is shown at the top level.
  static List<WorkoutSessionComment> threaded(
    Iterable<WorkoutSessionComment> comments,
  ) {
    final byDate = comments.toList()
      ..sort((a, b) => a.dateCreated.compareTo(b.dateCreated));
    final ids = {for (final comment in byDate) comment.id};
    return [
      for (final root in byDate)
        if (root.parentId == null || !ids.contains(root.parentId)) ...[
          root,
          ...byDate.where((reply) => reply.parentId == root.id),
        ],
    ];
  }

  /// Leaves out comments by anyone [viewer] blocked and comments hidden by
  /// moderation that are not their own, with the replies under them.
  static List<WorkoutSessionComment> visible(
    List<WorkoutSessionComment> comments,
    UserModel? viewer,
  ) {
    final hidden = {
      for (final comment in comments)
        if (hasBlocked(viewer, comment.authorId) ||
            (comment.hidden == true && comment.authorId != viewer?.userId))
          comment.id,
    };
    return [
      for (final comment in comments)
        if (!hidden.contains(comment.id) && !hidden.contains(comment.parentId))
          comment,
    ];
  }

  /// Everyone who could be mentioned: the reader, the people they follow,
  /// the session's author and everyone in the thread. The first occurrence
  /// wins, so a profile's name beats one frozen on an old comment.
  static List<MentionCandidate> knownPeople({
    required UserModel? viewer,
    required List<UserModel> following,
    required UserModel? sessionAuthor,
    required List<WorkoutSessionComment> comments,
  }) {
    final seen = <String>{};
    return [
      for (final user in [?viewer, ...following, ?sessionAuthor])
        if (fullNameOf(user) case final name?)
          MentionCandidate(
            id: user.userId,
            fullName: name,
            username: user.username,
          ),
      for (final comment in comments)
        if (comment.authorName case final name?)
          MentionCandidate(id: comment.authorId, fullName: name),
    ].where((candidate) => seen.add(candidate.id)).toList();
  }

  static final _mention = RegExp(r'(?:^|\s)@([\p{L}0-9_.]+)$', unicode: true);

  /// What follows a trailing `@` in [draft], or null when not mid-mention.
  static String? mentionQuery(String draft) =>
      _mention.firstMatch(draft)?.group(1);

  /// Up to five people whose first name, full name (without spaces) or
  /// handle starts with the query, never the reader.
  static List<MentionCandidate> suggestions(
    String draft,
    List<MentionCandidate> known, {
    required String? readerId,
  }) {
    final query = mentionQuery(draft)?.toLowerCase();
    if (query == null) return const [];
    return known
        .where(
          (candidate) =>
              candidate.id != readerId &&
              (candidate.firstName.toLowerCase().startsWith(query) ||
                  candidate.fullName
                      .toLowerCase()
                      .replaceAll(RegExp(r'\s'), '')
                      .startsWith(query) ||
                  (candidate.username?.startsWith(query) ?? false)),
        )
        .take(5)
        .toList();
  }

  /// [draft] with its trailing `@query` replaced by [candidate]'s mention
  /// and a space.
  static String insertMention(String draft, MentionCandidate candidate) {
    final query = mentionQuery(draft);
    if (query == null) return draft;
    return '${draft.substring(0, draft.length - query.length)}'
        '${candidate.mentionText} ';
  }

  /// The ids of [picked] whose mention is still in [text].
  static List<String> mentionedIds(
    String text,
    List<MentionCandidate> picked,
  ) => [
    for (final candidate in picked)
      if (text.contains('@${candidate.mentionText}')) candidate.id,
  ];

  /// Where each resolvable mention is in [comment]'s text, by both
  /// spellings: comments from before handles mention by first name.
  static List<(int, int)> mentionRanges(
    WorkoutSessionComment comment,
    List<MentionCandidate> known,
  ) {
    final names = {
      for (final candidate in known)
        if (comment.mentionedUserIds.contains(candidate.id)) ...[
          candidate.firstName,
          candidate.mentionText,
        ],
    };
    final ranges = <(int, int)>[];
    for (final name in names) {
      final needle = '@$name';
      var start = comment.text.indexOf(needle);
      while (start >= 0) {
        ranges.add((start, start + needle.length));
        start = comment.text.indexOf(needle, start + needle.length);
      }
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    // Overlaps (a first name inside a longer handle) keep the first.
    final merged = <(int, int)>[];
    for (final range in ranges) {
      if (merged.isEmpty || range.$1 >= merged.last.$2) merged.add(range);
    }
    return merged;
  }
}
