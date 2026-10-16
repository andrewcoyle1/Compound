import 'dart:async';
import 'dart:convert';

import 'package:app_settings/app_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:notifications_repository/src/deep_link.dart';
import 'package:notifications_repository/src/live_activity.dart';
import 'package:notifications_repository/src/local_reminders.dart';
import 'package:notifications_repository/src/notifications_repository.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:user_repository/user_repository.dart';

/// Reports an error the app cannot act on (a token that failed to save, an
/// unknown time zone): it goes to logging, never to the caller.
typedef NotificationErrorReporter = void Function(
  Object error,
  StackTrace stackTrace,
);

/// {@template firebase_notifications_repository}
/// A [NotificationsRepository] on Firebase Cloud Messaging (pushes and the
/// token) and `flutter_local_notifications` (the local reminders, and pushes
/// shown while the app is in front, which neither platform shows itself).
///
/// The push token and time zone go to `users/{uid}/private/settings`
/// through [UserRepository.mergePrivateSettings], which completes offline.
/// `onMessage` and `onMessageOpenedApp` default to Firebase Messaging's;
/// `localTimezone` to the device's IANA zone; `openSettings` to
/// `app_settings`' notification page.
/// {@endtemplate}
class FirebaseNotificationsRepository extends NotificationsRepository {
  /// {@macro firebase_notifications_repository}
  new({
    required this._messaging,
    required FlutterLocalNotificationsPlugin localNotifications,
    required UserRepository userRepository,
    required this._copy,
    required this._onError,
    Stream<RemoteMessage>? onMessage,
    Stream<RemoteMessage>? onMessageOpenedApp,
    Future<String> Function()? localTimezone,
    Future<void> Function()? openSettings,
  }) : _local = localNotifications,
       _users = userRepository,
       _onMessage = onMessage ?? FirebaseMessaging.onMessage,
       _onMessageOpenedApp =
           onMessageOpenedApp ?? FirebaseMessaging.onMessageOpenedApp,
       _localTimezone = localTimezone ?? _deviceTimezone,
       _openSettings = openSettings ?? _notificationSettings;

  /// The Android small icon: the app's monochrome `ic_notification`
  /// drawable (kept from resource shrinking by `res/raw/keep.xml`).
  static const androidIcon = '@drawable/ic_notification';

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;
  final UserRepository _users;
  final NotificationCopy _copy;
  final NotificationErrorReporter _onError;
  final Stream<RemoteMessage> _onMessage;
  final Stream<RemoteMessage> _onMessageOpenedApp;
  final Future<String> Function() _localTimezone;
  final Future<void> Function() _openSettings;

  final _messages = StreamController<PushMessage>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  StreamSubscription<String>? _tokenSubscription;

  static Future<void> _notificationSettings() =>
      AppSettings.openAppSettings(type: AppSettingsType.notification);

  static Future<String> _deviceTimezone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  @override
  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await _localTimezone()));
    } on Object catch (error, stackTrace) {
      // Daily reminders then fire on UTC's clock rather than not at all.
      _onError(error, stackTrace);
    }
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(androidIcon),
        // Permission is asked by `requestPermission`, when a feature needs it.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          deepLinks.store(_payloadLink(response.payload)),
    );
    // Made up front, so a push that arrives in the background (which the
    // system shows on `social`, the manifest's default) finds its channel.
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      for (final channel in NotificationChannel.values) {
        await _guard(
          () => android.createNotificationChannel(
            AndroidNotificationChannel(
              channel.name,
              _copy.channelName(channel),
              importance: _importance(channel),
            ),
          ),
        );
      }
    }
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      deepLinks.store(_payloadLink(launch!.notificationResponse?.payload));
    }
    _subscriptions
      ..add(_onMessage.listen(_present))
      ..add(
        _onMessageOpenedApp.listen(
          (message) => deepLinks.store(DeepLink.fromData(message.data)),
        ),
      );
    final initial = await _messaging.getInitialMessage();
    if (initial != null) deepLinks.store(DeepLink.fromData(initial.data));
  }

  static DeepLink? _payloadLink(String? payload) {
    if (payload == null) return null;
    final data = jsonDecode(payload);
    return data is Map<String, Object?> ? DeepLink.fromData(data) : null;
  }

  @override
  Future<PushPermission> permission() async =>
      _permission(await _messaging.getNotificationSettings());

  @override
  Future<bool> requestPermission() async =>
      _permission(await _messaging.requestPermission()).canDeliver;

  @override
  Future<void> openSystemSettings() => _guard(_openSettings);

  static PushPermission _permission(NotificationSettings settings) =>
      switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized => PushPermission.authorized,
        AuthorizationStatus.provisional => PushPermission.provisional,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      };

  @override
  Future<void> startPushTokenSync(String uid) async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (token) => unawaited(_saveToken(uid, token)),
    );
    try {
      // On iOS this throws until APNs has a token; `onTokenRefresh` then
      // delivers it.
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(uid, token);
    } on Object catch (error, stackTrace) {
      _onError(error, stackTrace);
    }
  }

  /// Merged into the private settings with the time zone, as
  /// `UserManager.saveUserFCMToken` does. Unlike Swift, never copied to the
  /// public profile, which followers can read.
  Future<void> _saveToken(String uid, String token) async {
    if (token.isEmpty) return;
    try {
      await _users.mergePrivateSettings(
        uid,
        PrivateUserSettings(fcmToken: token, timezone: await _localTimezone()),
      );
    } on Object catch (error, stackTrace) {
      _onError(error, stackTrace);
    }
  }

  @override
  Future<void> stopPushTokenSync() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    try {
      await _messaging.deleteToken();
    } on Object catch (error, stackTrace) {
      _onError(error, stackTrace);
    }
  }

  @override
  Stream<PushMessage> get foregroundMessages => _messages.stream;

  /// Shows a push that arrived in front as `PushManager` presents it: social
  /// activity quietly (it is already in the app), anything else as a banner.
  Future<void> _present(RemoteMessage remote) async {
    final type = remote.data['type'];
    final message = PushMessage(
      type: type is String ? type : null,
      title: remote.notification?.title,
      body: remote.notification?.body,
      link: DeepLink.fromData(remote.data),
    );
    _messages.add(message);
    if (remote.notification == null) return;
    final quiet =
        ForegroundPresentation.of(type: message.type) ==
        ForegroundPresentation.list;
    await _guard(
      () => _local.show(
        id: (remote.messageId ?? '${remote.sentTime}').hashCode & 0x7fffffff,
        title: message.title,
        body: message.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            NotificationChannel.social.name,
            _copy.channelName(NotificationChannel.social),
            icon: androidIcon,
            silent: quiet,
          ),
          iOS: DarwinNotificationDetails(
            presentBanner: !quiet,
            presentList: true,
            presentSound: !quiet,
          ),
        ),
        payload: jsonEncode(remote.data),
      ),
    );
  }

  @override
  Future<void> schedule(LocalReminder reminder) async {
    if (reminder.kind == LocalReminderKind.restOver &&
        await permission() == PushPermission.notDetermined) {
      await requestPermission();
    }
    final now = tz.TZDateTime.now(tz.local);
    final (date, repeat) = switch (reminder.schedule) {
      ReminderAt(:final at) => (tz.TZDateTime.from(at, tz.local), null),
      ReminderDaily(:final hour, :final minute) => (
        nextDaily(now, hour, minute),
        DateTimeComponents.time,
      ),
    };
    // The rest ran out before it could be scheduled: nothing to announce.
    if (!date.isAfter(now)) return;
    final text = _copy.reminder(reminder.kind);
    await _guard(
      () => _local.zonedSchedule(
        id: reminder.kind.id,
        scheduledDate: date,
        notificationDetails: _details(reminder),
        // Inexact needs no exact-alarm permission. The tracker's own timer
        // (and the ongoing notification) alerts on time; this stands in.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: text.title,
        body: reminder.body ?? text.body,
        payload: reminder.data == null ? null : jsonEncode(reminder.data),
        matchDateTimeComponents: repeat,
      ),
    );
  }

  /// The next [hour]:[minute] after [now], today or tomorrow.
  @visibleForTesting
  static tz.TZDateTime nextDaily(tz.TZDateTime now, int hour, int minute) {
    final today = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    return today.isAfter(now)
        ? today
        : tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day + 1,
            hour,
            minute,
          );
  }

  NotificationDetails _details(LocalReminder reminder) {
    final shown =
        ForegroundPresentation.of(kind: reminder.kind) !=
        ForegroundPresentation.none;
    final channel = reminder.kind.channel;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.name,
        _copy.channelName(channel),
        icon: androidIcon,
        importance: _importance(channel),
        priority: channel == NotificationChannel.workout
            ? Priority.high
            : Priority.defaultPriority,
        playSound: reminder.sound,
        silent: !reminder.sound,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: shown,
        presentBanner: shown,
        presentList: shown,
        presentSound: shown && reminder.sound,
        interruptionLevel: InterruptionLevel.values.byName(reminder.level.name),
      ),
    );
  }

  /// The workout channel is heads-up: its notifications are about now.
  static Importance _importance(NotificationChannel channel) =>
      channel == NotificationChannel.workout
      ? Importance.high
      : Importance.defaultImportance;

  @override
  Future<void> cancel(LocalReminderKind kind) =>
      _guard(() => _local.cancel(id: kind.id));

  @override
  bool get showsOngoingWorkout =>
      defaultTargetPlatform == TargetPlatform.android;

  /// Posted silently, so each update (a set logged, a rest started) changes
  /// it without a sound; with [OngoingWorkout.alert], heads-up with sound.
  /// The clock is Android's own chronometer, so nothing ticks here.
  @override
  Future<void> showOngoingWorkout(OngoingWorkout workout) async {
    if (!showsOngoingWorkout) return;
    const channel = NotificationChannel.workout;
    await _guard(
      () => _local.show(
        id: NotificationsRepository.ongoingWorkoutId,
        title: workout.title,
        body: workout.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.name,
            _copy.channelName(channel),
            icon: androidIcon,
            importance: _importance(channel),
            priority: workout.alert ? Priority.high : Priority.low,
            ongoing: true,
            autoCancel: false,
            silent: !workout.alert,
            category: AndroidNotificationCategory.workout,
            showWhen: workout.clock != null,
            when: workout.clock?.millisecondsSinceEpoch,
            usesChronometer: workout.clock != null,
            chronometerCountDown: workout.countsDown,
          ),
        ),
        payload: jsonEncode(const {'deep_link': 'compound://workout'}),
      ),
    );
  }

  @override
  Future<void> clearOngoingWorkout({OngoingWorkoutSummary? summary}) =>
      _guard(() => _local.cancel(id: NotificationsRepository.ongoingWorkoutId));

  /// ponytail: a push iOS showed itself (the app in the background) has no
  /// integer id for the plugin and stays; clear by identifier at M6 if it
  /// matters there.
  @override
  Future<void> clearDelivered() => _guard(() async {
    final kept = {
      for (final kind in LocalReminderKind.values) kind.id,
      NotificationsRepository.ongoingWorkoutId,
    };
    for (final shown in await _local.getActiveNotifications()) {
      final id = shown.id;
      if (id == null || kept.contains(id)) continue;
      await _local.cancel(id: id, tag: shown.tag);
    }
  });

  /// A notification that fails to schedule is dropped, as in Swift: the rest
  /// runs out whether or not anything announces it.
  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } on Object catch (error, stackTrace) {
      _onError(error, stackTrace);
    }
  }

  /// Stops listening; for tests and hot restarts.
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _tokenSubscription?.cancel();
    await _messages.close();
  }
}
