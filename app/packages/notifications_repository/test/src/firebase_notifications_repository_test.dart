import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:user_repository/user_repository.dart';

class _MockMessaging extends Mock implements FirebaseMessaging;

class _MockLocal extends Mock implements FlutterLocalNotificationsPlugin;

class _MockSettings extends Mock implements NotificationSettings;

class _MockAndroid extends Mock
    implements AndroidFlutterLocalNotificationsPlugin;

class _MockUserRepository extends Mock implements UserRepository;

class _Copy implements NotificationCopy {
  @override
  ({String title, String body}) reminder(LocalReminderKind kind) =>
      (title: 'title ${kind.name}', body: 'body ${kind.name}');

  @override
  String channelName(NotificationChannel channel) => 'channel ${channel.name}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz_data.initializeTimeZones();
    registerFallbackValue(tz.TZDateTime.utc(2026));
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    registerFallbackValue(DateTimeComponents.time);
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const PrivateUserSettings());
    registerFallbackValue(const AndroidNotificationChannel('id', 'name'));
  });

  group(FirebaseNotificationsRepository, () {
    late _MockMessaging messaging;
    late _MockLocal local;
    late InMemoryUserRepository users;
    late StreamController<RemoteMessage> onMessage;
    late StreamController<RemoteMessage> onOpened;
    late StreamController<String> onToken;
    late List<Object> errors;
    late FirebaseNotificationsRepository repository;
    late AuthorizationStatus status;
    late DidReceiveNotificationResponseCallback onTap;

    FirebaseNotificationsRepository build({
      UserRepository? userRepository,
      Future<String> Function()? localTimezone,
    }) => FirebaseNotificationsRepository(
      messaging: messaging,
      localNotifications: local,
      userRepository: userRepository ?? users,
      copy: _Copy(),
      onError: (error, _) => errors.add(error),
      onMessage: onMessage.stream,
      onMessageOpenedApp: onOpened.stream,
      localTimezone: localTimezone ?? () async => 'Europe/London',
    );

    NotificationSettings settings(AuthorizationStatus status) {
      final settings = _MockSettings();
      when(() => settings.authorizationStatus).thenReturn(status);
      return settings;
    }

    void stubSchedule() => when(
      () => local.zonedSchedule(
        id: any(named: 'id'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        payload: any(named: 'payload'),
        matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
      ),
    ).thenAnswer((_) async {});

    List<Object?> scheduled() => verify(
      () => local.zonedSchedule(
        id: captureAny(named: 'id'),
        scheduledDate: captureAny(named: 'scheduledDate'),
        notificationDetails: captureAny(named: 'notificationDetails'),
        androidScheduleMode: captureAny(named: 'androidScheduleMode'),
        title: captureAny(named: 'title'),
        body: captureAny(named: 'body'),
        payload: captureAny(named: 'payload'),
        matchDateTimeComponents: captureAny(named: 'matchDateTimeComponents'),
      ),
    ).captured;

    setUp(() {
      messaging = _MockMessaging();
      local = _MockLocal();
      users = InMemoryUserRepository();
      onMessage = StreamController();
      onOpened = StreamController();
      onToken = StreamController.broadcast();
      errors = [];
      status = AuthorizationStatus.authorized;
      when(() => messaging.getNotificationSettings())
          .thenAnswer((_) async => settings(status));
      when(() => messaging.requestPermission()).thenAnswer((_) async {
        status = AuthorizationStatus.authorized;
        return settings(status);
      });
      when(() => messaging.getInitialMessage()).thenAnswer((_) async => null);
      when(() => messaging.onTokenRefresh).thenAnswer((_) => onToken.stream);
      when(() => messaging.getToken()).thenAnswer((_) async => 'token-1');
      when(() => messaging.deleteToken()).thenAnswer((_) async {});
      when(
        () => local.initialize(
          settings: any(named: 'settings'),
          onDidReceiveNotificationResponse: any(
            named: 'onDidReceiveNotificationResponse',
          ),
        ),
      ).thenAnswer((invocation) async {
        onTap =
            invocation.namedArguments[#onDidReceiveNotificationResponse]
                as DidReceiveNotificationResponseCallback;
        return true;
      });
      when(() => local.getNotificationAppLaunchDetails())
          .thenAnswer((_) async => null);
      when(() => local.cancel(id: any(named: 'id'))).thenAnswer((_) async {});
      when(
        () => local.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});
      stubSchedule();
      repository = build();
    });

    tearDown(() => repository.dispose());

    group('initialize', () {
      test('sets the local time zone', () async {
        await repository.initialize();
        expect(tz.local.name, 'Europe/London');
        expect(errors, isEmpty);
      });

      test('an unknown time zone is reported, not thrown', () async {
        await build(localTimezone: () async => 'Mars/Olympus').initialize();
        expect(errors, hasLength(1));
      });

      test('reads the device time zone by default', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('flutter_timezone'),
              (_) async => 'Europe/Paris',
            );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('flutter_timezone'),
                null,
              ),
        );
        final defaults = FirebaseNotificationsRepository(
          messaging: messaging,
          localNotifications: local,
          userRepository: users,
          copy: _Copy(),
          onError: (error, _) => errors.add(error),
        );
        await defaults.initialize();
        expect(tz.local.name, 'Europe/Paris');
        await defaults.dispose();
      });

      test('makes the Android channels up front', () async {
        final android = _MockAndroid();
        when(() => android.createNotificationChannel(any()))
            .thenAnswer((_) async {});
        when(
          () => local
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(android);
        await repository.initialize();
        final channels = verify(
          () => android.createNotificationChannel(captureAny()),
        ).captured.cast<AndroidNotificationChannel>();
        expect(channels.map((c) => (c.id, c.name, c.importance)), [
          ('workout', 'channel workout', Importance.high),
          ('reminders', 'channel reminders', Importance.defaultImportance),
          ('social', 'channel social', Importance.defaultImportance),
        ]);
      });

      test('a tapped local notification is held for routing', () async {
        await repository.initialize();
        onTap(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: jsonEncode({'tab': 'nutrition'}),
          ),
        );
        expect(
          repository.deepLinks.pending,
          const TabLink(DeepLinkTab.nutrition),
        );
      });

      test('a tap with no payload, or not a map, goes nowhere', () async {
        await repository.initialize();
        onTap(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
          ),
        );
        onTap(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: '[1]',
          ),
        );
        expect(repository.deepLinks.pending, isNull);
      });

      test('a local notification that launched the app is held', () async {
        when(() => local.getNotificationAppLaunchDetails()).thenAnswer(
          (_) async => NotificationAppLaunchDetails(
            true,
            notificationResponse: NotificationResponse(
              notificationResponseType:
                  NotificationResponseType.selectedNotification,
              payload: jsonEncode({'tab': 'progress'}),
            ),
          ),
        );
        await repository.initialize();
        expect(
          repository.deepLinks.pending,
          const TabLink(DeepLinkTab.progress),
        );
      });

      test('a launch that was not from a notification holds nothing', () async {
        when(() => local.getNotificationAppLaunchDetails())
            .thenAnswer((_) async => const NotificationAppLaunchDetails(false));
        await repository.initialize();
        expect(repository.deepLinks.pending, isNull);
      });

      test('a push that launched the app is held', () async {
        when(() => messaging.getInitialMessage()).thenAnswer(
          (_) async => const RemoteMessage(data: {'type': 'follow_request'}),
        );
        await repository.initialize();
        expect(repository.deepLinks.pending, const NotificationsLink());
      });

      test('a push opened from the background is held', () async {
        await repository.initialize();
        onOpened.add(
          const RemoteMessage(
            data: {
              'type': 'like',
              'session_id': 's1',
              'session_author_id': 'u1',
            },
          ),
        );
        await pumpEventQueue();
        expect(
          repository.deepLinks.pending,
          const SessionLink(id: 's1', authorId: 'u1'),
        );
      });
    });

    group('permission', () {
      test('maps every status', () async {
        for (final (from, to) in [
          (AuthorizationStatus.authorized, PushPermission.authorized),
          (AuthorizationStatus.provisional, PushPermission.provisional),
          (AuthorizationStatus.denied, PushPermission.denied),
          (AuthorizationStatus.deniedPermanently, PushPermission.denied),
          (AuthorizationStatus.notDetermined, PushPermission.notDetermined),
        ]) {
          status = from;
          expect(await repository.permission(), to);
        }
      });

      test('asking answers whether notifications will be delivered', () async {
        expect(await repository.requestPermission(), isTrue);
        when(() => messaging.requestPermission())
            .thenAnswer((_) async => settings(AuthorizationStatus.denied));
        expect(await repository.requestPermission(), isFalse);
      });

      test('opens the notification settings, reporting a failure', () async {
        var opened = 0;
        final opener = FirebaseNotificationsRepository(
          messaging: messaging,
          localNotifications: local,
          userRepository: users,
          copy: _Copy(),
          onError: (error, _) => errors.add(error),
          onMessage: onMessage.stream,
          onMessageOpenedApp: onOpened.stream,
          openSettings: () async => opened++,
        );
        await opener.openSystemSettings();
        expect(opened, 1);
        expect(errors, isEmpty);

        final failing = FirebaseNotificationsRepository(
          messaging: messaging,
          localNotifications: local,
          userRepository: users,
          copy: _Copy(),
          onError: (error, _) => errors.add(error),
          onMessage: onMessage.stream,
          onMessageOpenedApp: onOpened.stream,
          openSettings: () async => throw StateError('no settings'),
        );
        await failing.openSystemSettings();
        expect(errors, hasLength(1));
      });

      test("opens app_settings' notification page by default", () async {
        const channel = MethodChannel('com.spencerccf.app_settings/methods');
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        await repository.openSystemSettings();
        expect(calls, hasLength(1));
        expect(errors, isEmpty);
      });
    });

    group('push token', () {
      test(
        'goes to private settings with the time zone, never the profile',
        () async {
          await users.createUser(const UserModel(userId: 'uid'));
          await repository.startPushTokenSync('uid');
          final stored = await users.watchPrivateSettings('uid').first;
          expect(stored?.fcmToken, 'token-1');
          expect(stored?.timezone, 'Europe/London');
          final profile = await users.watchUser('uid').first;
          expect(profile?.toFirestore().containsKey('fcm_token'), isFalse);
        },
      );

      test('a refreshed token is saved; an empty one is not', () async {
        when(() => messaging.getToken()).thenAnswer((_) async => null);
        await repository.startPushTokenSync('uid');
        expect(await users.watchPrivateSettings('uid').first, isNull);

        onToken.add('');
        await pumpEventQueue();
        expect(await users.watchPrivateSettings('uid').first, isNull);

        onToken.add('token-2');
        await pumpEventQueue();
        expect(
          (await users.watchPrivateSettings('uid').first)?.fcmToken,
          'token-2',
        );
      });

      test('a token APNs has not provided yet is reported', () async {
        when(() => messaging.getToken()).thenThrow(Exception('apns'));
        await repository.startPushTokenSync('uid');
        expect(errors, hasLength(1));
      });

      test('a save that fails to start is reported', () async {
        final failing = _MockUserRepository();
        when(() => failing.mergePrivateSettings(any(), any()))
            .thenThrow(Exception('write'));
        final other = build(userRepository: failing);
        await other.startPushTokenSync('uid');
        expect(errors, hasLength(1));
        await other.dispose();
      });

      test('a new sign-in replaces the last listener', () async {
        await repository.startPushTokenSync('first');
        await repository.startPushTokenSync('second');
        onToken.add('token-3');
        await pumpEventQueue();
        expect(
          (await users.watchPrivateSettings('first').first)?.fcmToken,
          'token-1',
        );
        expect(
          (await users.watchPrivateSettings('second').first)?.fcmToken,
          'token-3',
        );
      });

      test('sign-out stops syncing and retires the token', () async {
        await repository.startPushTokenSync('uid');
        await repository.stopPushTokenSync();
        verify(() => messaging.deleteToken()).called(1);
        expect(onToken.hasListener, isFalse);

        when(() => messaging.deleteToken()).thenThrow(Exception('offline'));
        await repository.stopPushTokenSync();
        expect(errors, hasLength(1));
      });
    });

    group('foreground messages', () {
      test('social activity is published and shown quietly', () async {
        await repository.initialize();
        final messages = <PushMessage>[];
        repository.foregroundMessages.listen(messages.add);
        const data = {
          'tab': 'dashboard',
          'type': 'comment',
          'session_id': 's1',
          'session_author_id': 'u1',
        };
        onMessage.add(
          const RemoteMessage(
            messageId: 'm1',
            data: data,
            notification: RemoteNotification(title: 'Jane', body: 'Nice'),
          ),
        );
        await pumpEventQueue();
        expect(messages, [
          const PushMessage(
            type: 'comment',
            title: 'Jane',
            body: 'Nice',
            link: SessionLink(id: 's1', authorId: 'u1', openComments: true),
          ),
        ]);
        final captured = verify(
          () => local.show(
            id: captureAny(named: 'id'),
            title: 'Jane',
            body: 'Nice',
            notificationDetails: captureAny(named: 'notificationDetails'),
            payload: jsonEncode(data),
          ),
        ).captured;
        expect(captured[0], 'm1'.hashCode & 0x7fffffff);
        final details = captured[1] as NotificationDetails;
        expect(details.android?.channelId, 'social');
        expect(details.android?.channelName, 'channel social');
        expect(details.android?.silent, isTrue);
        expect(details.iOS?.presentBanner, isFalse);
        expect(details.iOS?.presentList, isTrue);
      });

      test('anything else is a banner', () async {
        await repository.initialize();
        onMessage.add(
          RemoteMessage(
            sentTime: DateTime.utc(2026),
            data: const {'tab': 'training', 'type': 'streakReminder'},
            notification: const RemoteNotification(title: 'Streak at Risk'),
          ),
        );
        await pumpEventQueue();
        final details =
            verify(
                  () => local.show(
                    id: any(named: 'id'),
                    title: 'Streak at Risk',
                    notificationDetails: captureAny(
                      named: 'notificationDetails',
                    ),
                    payload: any(named: 'payload'),
                  ),
                ).captured.single
                as NotificationDetails;
        expect(details.android?.silent, isFalse);
        expect(details.iOS?.presentBanner, isTrue);
      });

      test('a data-only push is published but not shown', () async {
        await repository.initialize();
        final messages = <PushMessage>[];
        repository.foregroundMessages.listen(messages.add);
        onMessage.add(const RemoteMessage(data: {'type': 3}));
        await pumpEventQueue();
        expect(messages, [const PushMessage()]);
        verifyNever(
          () => local.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          ),
        );
      });
    });

    group('local reminders', () {
      setUp(() => repository.initialize());

      test(
        'the rest timer asks first, then schedules quietly in front',
        () async {
          status = AuthorizationStatus.notDetermined;
          final at = DateTime.now().add(const Duration(minutes: 2));
          await repository.schedule(
            LocalReminders.restOver(at: at, body: 'Next: Squat', sound: false),
          );
          verify(() => messaging.requestPermission()).called(1);
          final captured = scheduled();
          expect(captured[0], 7);
          expect(
            (captured[1]! as tz.TZDateTime).millisecondsSinceEpoch,
            at.millisecondsSinceEpoch,
          );
          final details = captured[2]! as NotificationDetails;
          expect(details.android?.channelId, 'workout');
          expect(details.android?.importance, Importance.high);
          expect(details.android?.silent, isTrue);
          expect(
            details.iOS?.interruptionLevel,
            InterruptionLevel.timeSensitive,
          );
          expect(details.iOS?.presentBanner, isFalse);
          expect(details.iOS?.presentSound, isFalse);
          expect(captured[3], AndroidScheduleMode.inexactAllowWhileIdle);
          expect(captured[4], 'title restOver');
          expect(captured[5], 'Next: Squat');
          expect(captured[6], isNull);
          expect(captured[7], isNull);
        },
      );

      test('the rest timer does not ask again', () async {
        await repository.schedule(
          LocalReminders.restOver(
            at: DateTime.now().add(const Duration(minutes: 1)),
          ),
        );
        verifyNever(() => messaging.requestPermission());
      });

      test('meal reminders repeat daily and open Nutrition', () async {
        await repository.schedule(LocalReminders.meals().first);
        final captured = scheduled();
        expect(captured[0], 4);
        final date = captured[1]! as tz.TZDateTime;
        expect((date.hour, date.minute), (8, 0));
        final details = captured[2]! as NotificationDetails;
        expect(details.android?.channelId, 'reminders');
        expect(details.android?.importance, Importance.defaultImportance);
        expect(details.iOS?.interruptionLevel, InterruptionLevel.passive);
        expect(details.iOS?.presentBanner, isTrue);
        expect(captured[4], 'title breakfast');
        expect(captured[5], 'body breakfast');
        expect(captured[6], jsonEncode({'tab': 'nutrition'}));
        expect(captured[7], DateTimeComponents.time);
      });

      test('a time already past is not scheduled', () async {
        await repository.schedule(
          LocalReminders.restOver(
            at: DateTime.now().subtract(const Duration(seconds: 1)),
          ),
        );
        verifyNever(
          () => local.zonedSchedule(
            id: any(named: 'id'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: any(named: 'payload'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
          ),
        );
      });

      test('a failure to schedule is reported, not thrown', () async {
        when(
          () => local.zonedSchedule(
            id: any(named: 'id'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            payload: any(named: 'payload'),
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
          ),
        ).thenThrow(Exception('denied'));
        await repository.schedule(
          LocalReminders.idleWorkout(
            lastLog: DateTime.now(),
            now: DateTime.now(),
          )!,
        );
        expect(errors, hasLength(1));
      });

      test('cancel withdraws by id', () async {
        await repository.cancel(LocalReminderKind.idleWorkout);
        verify(() => local.cancel(id: 8)).called(1);
      });

      test('settings schedule the come-back reminders', () async {
        await repository.applyReminderSettings(const PrivateUserSettings());
        expect(scheduled().whereType<int>().take(3), [1, 2, 3]);
      });
    });

    group('ongoing workout', () {
      const workout = OngoingWorkout(title: 'Push Day', body: 'Next: Bench');

      tearDown(() => debugDefaultTargetPlatformOverride = null);

      test('shows on Android only', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(repository.showsOngoingWorkout, isFalse);
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        expect(repository.showsOngoingWorkout, isTrue);
      });

      test('is not posted where it does not show', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await repository.showOngoingWorkout(workout);
        verifyNever(
          () => local.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          ),
        );
      });

      NotificationDetails shown() =>
          verify(
                () => local.show(
                  id: 9,
                  title: 'Push Day',
                  body: 'Next: Bench',
                  notificationDetails: captureAny(named: 'notificationDetails'),
                  payload: '{"deep_link":"compound://workout"}',
                ),
              ).captured.single
              as NotificationDetails;

      test('counts down a rest, silently, and opens the tracker', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final end = DateTime.utc(2026, 10, 15, 9, 2);
        await repository.showOngoingWorkout(
          OngoingWorkout(
            title: 'Push Day',
            body: 'Next: Bench',
            clock: end,
            countsDown: true,
          ),
        );
        final android = shown().android!;
        expect(android.channelId, 'workout');
        expect(android.ongoing, isTrue);
        expect(android.autoCancel, isFalse);
        expect(android.silent, isTrue);
        expect(android.priority, Priority.low);
        expect(android.usesChronometer, isTrue);
        expect(android.chronometerCountDown, isTrue);
        expect(android.when, end.millisecondsSinceEpoch);
        expect(android.showWhen, isTrue);
      });

      test('alerts once at the end of a rest; no clock while paused', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await repository.showOngoingWorkout(
          const OngoingWorkout(
            title: 'Push Day',
            body: 'Next: Bench',
            alert: true,
          ),
        );
        final android = shown().android!;
        expect(android.silent, isFalse);
        expect(android.priority, Priority.high);
        expect(android.usesChronometer, isFalse);
        expect(android.showWhen, isFalse);
      });

      test('is cleared by id', () async {
        await repository.clearOngoingWorkout();
        verify(() => local.cancel(id: 9)).called(1);
      });

      test(
        'delivered pushes are cleared; reminders and the workout stay',
        () async {
          when(
            () => local.cancel(
              id: any(named: 'id'),
              tag: any(named: 'tag'),
            ),
          ).thenAnswer((_) async {});
          when(() => local.getActiveNotifications()).thenAnswer(
            (_) async => const [
              ActiveNotification(id: 0, tag: 'FCM-Notification:1'),
              ActiveNotification(id: 123456),
              ActiveNotification(id: 9),
              ActiveNotification(id: 1),
              ActiveNotification(id: 7),
              ActiveNotification(),
            ],
          );
          await repository.clearDelivered();
          verify(() => local.cancel(id: 0, tag: 'FCM-Notification:1'))
              .called(1);
          verify(() => local.cancel(id: 123456)).called(1);
          verifyNever(() => local.cancel(id: 9, tag: any(named: 'tag')));
          verifyNever(() => local.cancel(id: 1, tag: any(named: 'tag')));
          verifyNever(() => local.cancel(id: 7, tag: any(named: 'tag')));
        },
      );

      test('a platform that cannot list them reports and carries on', () async {
        when(() => local.getActiveNotifications())
            .thenThrow(UnsupportedError('old'));
        await repository.clearDelivered();
        expect(errors, hasLength(1));
      });

      test('compares by value', () {
        expect(
          // Not const, so equality goes through props.
          // ignore: prefer_const_constructors
          OngoingWorkout(title: 'Push Day', body: 'Next: Bench'),
          workout,
        );
      });
    });

    group('nextDaily', () {
      tz.Location london() => tz.getLocation('Europe/London');

      test('later today when the time is still ahead', () {
        tz.setLocalLocation(london());
        final now = tz.TZDateTime(london(), 2026, 10, 15, 7, 59);
        expect(
          FirebaseNotificationsRepository.nextDaily(now, 8, 0),
          tz.TZDateTime(tz.local, 2026, 10, 15, 8),
        );
      });

      test('tomorrow once it has passed, on the clock across a change', () {
        tz.setLocalLocation(london());
        final now = tz.TZDateTime(london(), 2026, 10, 24, 8);
        final next = FirebaseNotificationsRepository.nextDaily(now, 8, 0);
        expect((next.day, next.hour), (25, 8));
      });
    });
  });
}
