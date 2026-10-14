import 'package:analytics_repository/analytics_repository.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics;

void main() {
  group(CrashlyticsService, () {
    late _MockFirebaseCrashlytics crashlytics;
    late CrashlyticsService service;

    setUp(() {
      crashlytics = _MockFirebaseCrashlytics();
      when(() => crashlytics.log(any())).thenAnswer((_) async {});
      when(
        () => crashlytics.recordError(
          any<Object?>(),
          any(),
          reason: any<Object?>(named: 'reason'),
          information: any(named: 'information'),
        ),
      ).thenAnswer((_) async {});
      when(() => crashlytics.setUserIdentifier(any())).thenAnswer((_) async {});
      when(() => crashlytics.setCustomKey(any(), any()))
          .thenAnswer((_) async {});
      service = CrashlyticsService(crashlytics: crashlytics);
    });

    test('leaves a breadcrumb for an event that is not severe', () async {
      await service.trackEvent(
        const AnalyticsEvent('Auth_Listener_Empty', type: LogType.warning),
      );
      await service.trackScreenView(const AnalyticsEvent('TodayView_Appear'));
      verify(() => crashlytics.log('warning: Auth_Listener_Empty')).called(1);
      verify(() => crashlytics.log('analytic: TodayView_Appear')).called(1);
      verifyNoMoreInteractions(crashlytics);
    });

    test('records a severe event as a non-fatal error', () async {
      await service.trackEvent(
        const AnalyticsEvent(
          'TodayView_StartBlankWorkout_Fail',
          parameters: {'error_code': 7},
          type: LogType.severe,
        ),
      );
      await service.trackEvent(
        const AnalyticsEvent('Bare_Fail', type: LogType.severe),
      );
      verify(
        () => crashlytics.recordError(
          'TodayView_StartBlankWorkout_Fail',
          any(),
          reason: 'TodayView_StartBlankWorkout_Fail',
          information: ['error_code: 7'],
        ),
      ).called(1);
      verify(
        () => crashlytics.recordError(
          'Bare_Fail',
          any(),
          reason: 'Bare_Fail',
          information: <Object>[],
        ),
      ).called(1);
    });

    test('sets the user identifier', () async {
      await service.identifyUser(userId: 'uid', name: 'A', email: 'a@b.c');
      verify(() => crashlytics.setUserIdentifier('uid')).called(1);
      verifyNoMoreInteractions(crashlytics);
    });

    test('sets only high-priority user properties as custom keys', () async {
      await service.addUserProperties({'low': 1});
      await service.addUserProperties({
        'text': 'a',
        'count': 2,
        'flag': true,
        'list': ['x'],
        'missing': null,
      }, isHighPriority: true);
      verify(() => crashlytics.setCustomKey('text', 'a')).called(1);
      verify(() => crashlytics.setCustomKey('count', 2)).called(1);
      verify(() => crashlytics.setCustomKey('flag', true)).called(1);
      verify(() => crashlytics.setCustomKey('list', '[x]')).called(1);
      verifyNoMoreInteractions(crashlytics);
    });

    test('clears the user identifier when the profile is deleted', () async {
      await service.deleteUserProfile();
      verify(() => crashlytics.setUserIdentifier('')).called(1);
    });
  });
}
