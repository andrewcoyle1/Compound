import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the device has a network (Swift's `NetworkMonitor`), for the
/// actions that need the server to answer before they can finish: Cloud
/// Function calls, uploads, claiming a username, sharing and invites.
/// Plain Firestore writes do not ask; Firestore queues them.
///
/// Like Swift's monitor it keeps the last status it was told, so the check
/// is synchronous and a busy flag set straight after it cannot be raced.
class ConnectivityRepository {
  /// Follows connectivity_plus, or [check] and [changes] in its place: the
  /// status now, then every change.
  new({
    Future<List<ConnectivityResult>> Function()? check,
    Stream<List<ConnectivityResult>>? changes,
  }) {
    final connectivity = check == null || changes == null
        ? Connectivity()
        : null;
    unawaited(
      (check ?? connectivity!.checkConnectivity)().then(
        _update,
        onError: (Object _) {},
      ),
    );
    _changes = (changes ?? connectivity!.onConnectivityChanged).listen(
      _update,
      onError: (Object _) {},
    );
  }

  late final StreamSubscription<List<ConnectivityResult>> _changes;
  final _blocked = StreamController<void>.broadcast();

  /// Online until the first status arrives: an unknown status should not
  /// block anything, as in Swift.
  var _offline = false;

  void _update(List<ConnectivityResult> connections) => _offline =
      connections.isNotEmpty &&
      connections.every((c) => c == ConnectivityResult.none);

  /// Whether every connection is down, as last heard.
  bool get isOffline => _offline;

  /// Swift's `ensureOnline`, before an action that needs the server: true
  /// with a network; without one, false after telling [blocked], where the
  /// app says "You're offline".
  bool ensureOnline() {
    if (!isOffline) return true;
    _blocked.add(null);
    return false;
  }

  /// An action was not started for want of a network.
  Stream<void> get blocked => _blocked.stream;

  /// Stops following the device's status.
  Future<void> dispose() => _changes.cancel();
}

/// [ConnectivityRepository] for the staging flavor and tests: online until
/// [offline] is set.
class FakeConnectivityRepository extends ConnectivityRepository {
  /// Online unless [offline].
  new({this.offline = false})
    : super(check: _online, changes: const Stream.empty());

  /// Whether there is no network.
  bool offline;

  static Future<List<ConnectivityResult>> _online() async => const [
    ConnectivityResult.wifi,
  ];

  @override
  bool get isOffline => offline || super.isOffline;
}
