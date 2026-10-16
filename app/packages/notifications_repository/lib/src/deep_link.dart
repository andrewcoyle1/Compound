import 'package:equatable/equatable.dart';

/// The tab bar's roots, as in the Swift app's `DeepLink.Tab`.
enum DeepLinkTab {
  /// What to do now.
  today,

  /// The training plan and library.
  training,

  /// The nutrition plan and library.
  nutrition,

  /// The trends.
  progress,

  /// Everyone else.
  social;

  /// The tab for [name], or `null`. Names from before the tabs were split by
  /// job still land somewhere: "dashboard", "search" and "add" open Today,
  /// "analytics" opens Progress (`DeepLink.swift`, `Tab.init(name:)`).
  static DeepLinkTab? fromName(String name) => switch (name) {
    'dashboard' || 'search' || 'add' => today,
    'analytics' => progress,
    _ => values.asNameMap()[name],
  };

  /// The tab's router path, `/today` … `/social`.
  String get path => '/$name';
}

/// A destination the app can be sent to from outside it: a `compound://` URL
/// or a push or local notification's data. Mirrors the Swift `DeepLink`.
///
/// There are no https universal links: the Swift app has no associated
/// domains, so `compound://` is the only scheme.
sealed class DeepLink extends Equatable {
  /// Subclasses only.
  const new();

  /// Parses `compound://tab/nutrition`, tolerating `compound://tab?name=…`
  /// (or `?tab=…`), plus `compound://join/<code>` and `compound://workout`.
  /// Anything unrecognised is `null`: an unknown link does nothing visible
  /// rather than landing somewhere arbitrary. Like Swift, the scheme is not
  /// checked; the host decides.
  static DeepLink? parse(Uri uri) {
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments.where((s) => s.isNotEmpty);
    final firstPath = segments.isEmpty ? null : segments.first.toLowerCase();
    if (host == 'join') {
      final code = firstPath == null ? null : _normalisedInviteCode(firstPath);
      return code == null ? null : JoinLink(code);
    }
    if (host == 'workout') return const WorkoutLink();
    if (host != 'tab') return null;
    final queryName = uri.queryParameters.entries
        .where((e) => const {'name', 'tab'}.contains(e.key.toLowerCase()))
        .map((e) => e.value.toLowerCase())
        .firstOrNull;
    final name = firstPath ?? queryName;
    final tab = name == null ? null : DeepLinkTab.fromName(name);
    return tab == null ? null : TabLink(tab);
  }

  /// The same destinations from a notification's data, as
  /// `DeepLink(pushUserInfo:)` reads it: `deep_link` as a full URL, then a
  /// `follow_request` type as [NotificationsLink], then `session_id` with
  /// `session_author_id` (both non-empty) as a [SessionLink], then `tab` as a
  /// bare name. The keys are what `functions/lib.js` puts in `data`.
  static DeepLink? fromData(Map<String, Object?> data) {
    final link = data['deep_link'];
    final uri = link is String ? Uri.tryParse(link) : null;
    if (uri != null) return parse(uri);
    final type = data['type'];
    if (type == 'follow_request') return const NotificationsLink();
    final id = data['session_id'];
    final authorId = data['session_author_id'];
    if (id is String &&
        id.isNotEmpty &&
        authorId is String &&
        authorId.isNotEmpty) {
      return SessionLink(
        id: id,
        authorId: authorId,
        openComments: type == 'comment' || type == 'mention',
      );
    }
    final name = data['tab'];
    final tab = name is String
        ? DeepLinkTab.fromName(name.toLowerCase())
        : null;
    return tab == null ? null : TabLink(tab);
  }

  /// Where the Flutter router goes for this link. Destinations not built yet
  /// land on the tab Swift opens them from: Social for sessions by others,
  /// notifications and invites; Today for the workout widget.
  /// [currentUserId] lets a session the user wrote open in their history.
  String toLocation({String? currentUserId});

  /// The invite code in [raw], upper-cased with spaces and dashes dropped,
  /// or `null` (`InviteCode.normalised`; a copy of social_repository's,
  /// whose dependencies conflict with this package's).
  static String? _normalisedInviteCode(String raw) {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final code = raw.toUpperCase().replaceAll(RegExp('[ -]'), '');
    return code.length == 8 && code.split('').every(alphabet.contains)
        ? code
        : null;
  }
}

/// One of the tab bar's roots.
class const TabLink(final DeepLinkTab tab) extends DeepLink {
  /// A link to [tab].
  this;

  @override
  String toLocation({String? currentUserId}) => tab.path;

  @override
  List<Object?> get props => [tab];
}

/// One workout session, from a like, comment or mention push; with its
/// comments on top when [openComments] is set.
class const SessionLink({
  required final String id,
  required final String authorId,
  final bool openComments = false,
}) extends DeepLink {
  /// A link to session [id] by [authorId].
  this;

  /// The user's own session opens in their workout history; anyone else's
  /// lands on Social until the social screens exist.
  @override
  String toLocation({String? currentUserId}) => authorId == currentUserId
      ? '${DeepLinkTab.training.path}/history/$id'
      : DeepLinkTab.social.path;

  @override
  List<Object?> get props => [id, authorId, openComments];
}

/// The notifications screen, from a follow-request push.
class const NotificationsLink() extends DeepLink {
  /// A link to the notifications screen.
  this;

  /// The inbox, over Social as Swift opens it from Social's bell.
  @override
  String toLocation({String? currentUserId}) =>
      '${DeepLinkTab.social.path}/notifications';

  @override
  List<Object?> get props => [];
}

/// `compound://join/<code>`, an invite a friend sent; [code] is normalised.
class const JoinLink(final String code) extends DeepLink {
  /// A link accepting invite [code].
  this;

  @override
  String toLocation({String? currentUserId}) => DeepLinkTab.social.path;

  @override
  List<Object?> get props => [code];
}

/// `compound://workout`, from the Today's Workout widget: the tracker when a
/// session is under way, otherwise Today.
class const WorkoutLink() extends DeepLink {
  /// A link to the workout under way.
  this;

  @override
  String toLocation({String? currentUserId}) => DeepLinkTab.today.path;

  @override
  List<Object?> get props => [];
}
