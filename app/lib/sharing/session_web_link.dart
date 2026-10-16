import 'package:compound_models/compound_models.dart';
import 'package:notifications_repository/notifications_repository.dart';

/// A finished workout's public web page (Swift's `SessionWebLink`),
/// `<base>/<authorId>/<sessionId>`, rendered by the `sessionPage` Cloud
/// Function behind Hosting's `/s/**` rewrite. [base] is on the host of the
/// Firebase project the flavor talks to, passed in by its `main_*.dart`.
class const SessionWebLink(
  /// `https://<project>.web.app/s`.
  final Uri base,
) {
  /// The link, or null where the page would answer 404: no [author] (still
  /// loading or unknown), a private author, or a session that is
  /// unfinished, deleted or hidden by moderation.
  Uri? url(WorkoutSessionModel session, {required UserModel? author}) {
    if (author == null ||
        author.isPrivate == true ||
        session.endedAt == null ||
        session.deletedAt != null ||
        session.hidden == true) {
      return null;
    }
    return base.replace(
      pathSegments: [..._segments(base), session.authorId, session.id],
    );
  }

  /// The session [uri] links to when it is one of these pages, opened from
  /// outside the app; otherwise null.
  SessionLink? parse(Uri uri) {
    if (!uri.isScheme(base.scheme) ||
        uri.host.toLowerCase() != base.host.toLowerCase()) {
      return null;
    }
    final prefix = _segments(base);
    final segments = _segments(uri);
    if (segments.length != prefix.length + 2) return null;
    for (var i = 0; i < prefix.length; i++) {
      if (segments[i] != prefix[i]) return null;
    }
    return SessionLink(id: segments.last, authorId: segments[prefix.length]);
  }

  static List<String> _segments(Uri uri) => [
    for (final segment in uri.pathSegments)
      if (segment.isNotEmpty) segment,
  ];
}
