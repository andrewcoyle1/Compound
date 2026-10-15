import 'dart:async';

import 'package:notifications_repository/src/deep_link.dart';
import 'package:notifications_repository/src/local_reminders.dart';
import 'package:notifications_repository/src/notifications_repository.dart';

/// {@template fake_notifications_repository}
/// A [NotificationsRepository] with no platform plugins, for the staging
/// (mock) flavor and tests. Permission starts as [permissionState]; asking
/// grants it. Scheduled reminders are kept in [scheduled]; [receive] and
/// [tap] stand in for a push arriving and a notification being tapped.
/// {@endtemplate}
class FakeNotificationsRepository extends NotificationsRepository {
  /// {@macro fake_notifications_repository}
  new({this.permissionState = PushPermission.notDetermined});

  /// What [permission] answers.
  PushPermission permissionState;

  /// The uid whose token is being synced, or `null`.
  String? tokenUserId;

  /// The pending reminders, by kind.
  final Map<LocalReminderKind, LocalReminder> scheduled = {};

  final _messages = StreamController<PushMessage>.broadcast(sync: true);

  @override
  Future<void> initialize() async {}

  @override
  Future<PushPermission> permission() async => permissionState;

  @override
  Future<bool> requestPermission() async {
    if (permissionState == PushPermission.notDetermined) {
      permissionState = PushPermission.authorized;
    }
    return permissionState.canDeliver;
  }

  @override
  Future<void> startPushTokenSync(String uid) async => tokenUserId = uid;

  @override
  Future<void> stopPushTokenSync() async => tokenUserId = null;

  @override
  Stream<PushMessage> get foregroundMessages => _messages.stream;

  @override
  Future<void> schedule(LocalReminder reminder) async {
    if (reminder.kind == LocalReminderKind.restOver) await requestPermission();
    scheduled[reminder.kind] = reminder;
  }

  @override
  Future<void> cancel(LocalReminderKind kind) async => scheduled.remove(kind);

  /// A push arriving while the app is in front.
  void receive(PushMessage message) => _messages.add(message);

  /// A notification with [data] being tapped.
  void tap(Map<String, Object?> data) =>
      deepLinks.store(DeepLink.fromData(data));
}
