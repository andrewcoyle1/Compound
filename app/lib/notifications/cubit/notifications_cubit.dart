import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:compound/sharing/session_web_link.dart';
import 'package:equatable/equatable.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:user_repository/user_repository.dart';

part 'notifications_state.dart';

/// The app's side of notifications (`PushManager`'s sign-in and launch
/// work): the signed-in user's push token and time zone kept in their
/// private settings, their come-back and meal reminders kept in line with
/// those settings (and moved out on each return to the app), and the links
/// that taps and `compound://` URLs bring, handed to the router once someone
/// is signed in and past onboarding.
class NotificationsCubit extends Cubit<NotificationsState> {
  new({
    required this._notifications,
    required this._users,
    this._now = DateTime.now,
    this._webLink,
  }) : super(const NotificationsState()) {
    _links = _notifications.deepLinks.changes.listen((_) => _routePending());
  }

  final NotificationsRepository _notifications;
  final UserRepository _users;
  final DateTime Function() _now;

  /// The flavor's workout web pages, which open the workout in the app.
  final SessionWebLink? _webLink;

  late final StreamSubscription<void> _links;
  StreamSubscription<PrivateUserSettings?>? _settingsSubscription;
  String? _uid;
  bool _ready = false;
  PrivateUserSettings? _settings;

  /// The reminder switches last applied, so a token or time-zone write to
  /// the same settings document does not reschedule everything.
  (bool, bool)? _applied;

  /// Follows the signed-in user [uid]; [ready] once links can be routed
  /// (signed in, profile read, onboarding done). A new account starts its
  /// token sync and reminders; signing out retires this device's token.
  Future<void> userChanged(String? uid, {required bool ready}) async {
    if (ready != _ready) {
      _ready = ready;
      // Not ready drops a held link: it was meant for the account leaving.
      _notifications.deepLinks.setReady(ready: ready);
    }
    if (uid == _uid) return;
    final previous = _uid;
    _uid = uid;
    unawaited(_settingsSubscription?.cancel());
    _settingsSubscription = null;
    _settings = null;
    _applied = null;
    if (previous != null) await _notifications.stopPushTokenSync();
    if (uid == null || _uid != uid) return;
    await _notifications.startPushTokenSync(uid);
    if (isClosed || _uid != uid) return;
    // Reminders are a nicety: settings that cannot be read leave them be.
    try {
      _settingsSubscription = _users
          .watchPrivateSettings(uid)
          .listen(
            (settings) => unawaited(_settingsChanged(settings)),
            onError: (Object _, StackTrace _) {},
          );
    } on Object {
      return;
    }
  }

  Future<void> _settingsChanged(PrivateUserSettings? settings) async {
    final current = settings ?? const PrivateUserSettings();
    _settings = current;
    final switches = (
      current.isComeBackRemindersEnabled,
      current.isMealRemindersEnabled,
    );
    if (switches == _applied) return;
    _applied = switches;
    await _notifications.applyReminderSettings(current, now: _now());
  }

  /// The app is back in front: the come-back reminders move out to a day,
  /// three and five days from now.
  Future<void> resumed() async {
    final settings = _settings;
    if (settings == null) return;
    await _notifications.applyReminderSettings(settings, now: _now());
  }

  /// A `compound://` URL, or a workout's web page, the platform opened the
  /// app with; held like a tap until it can be routed. One the app doesn't
  /// know does nothing.
  void linkOpened(Uri uri) => _notifications.deepLinks.store(
    _webLink?.parse(uri) ?? DeepLink.parse(uri),
  );

  void _routePending() {
    final link = _notifications.deepLinks.consume();
    if (link == null || isClosed) return;
    emit(NotificationsState(link: link, linkId: state.linkId + 1));
  }

  @override
  Future<void> close() async {
    unawaited(_links.cancel());
    unawaited(_settingsSubscription?.cancel());
    await super.close();
  }
}
