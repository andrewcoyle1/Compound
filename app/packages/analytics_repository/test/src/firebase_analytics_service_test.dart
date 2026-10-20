import 'package:analytics_repository/analytics_repository.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAnalytics extends Mock implements FirebaseAnalytics;

void main() {
  group(FirebaseAnalyticsService, () {
    late _MockFirebaseAnalytics analytics;
    late FirebaseAnalyticsService service;

    setUp(() {
      analytics = _MockFirebaseAnalytics();
      when(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});
      when(() => analytics.logScreenView(screenName: any(named: 'screenName')))
          .thenAnswer((_) async {});
      when(() => analytics.setUserId(id: any(named: 'id')))
          .thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty(
          name: any(named: 'name'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      service = FirebaseAnalyticsService(analytics: analytics);
    });

    test('logs an event with cleaned name and parameters', () async {
      await service.trackEvent(
        AnalyticsEvent(
          'Auth SignIn Success ${'x' * 40}',
          parameters: const {'is_new_user': true, 'list': <Object>[]},
        ),
      );
      verify(
        () => analytics.logEvent(
          name: 'Auth_SignIn_Success_${'x' * 20}',
          parameters: {'is_new_user': 1, 'list': ''},
        ),
      ).called(1);
    });

    test('logs an event with no usable parameters as having none', () async {
      await service.trackEvent(
        const AnalyticsEvent('E', parameters: {'missing': null}),
      );
      verify(() => analytics.logEvent(name: 'E')).called(1);
    });

    test('logs a screen view', () async {
      await service.trackScreenView(const AnalyticsEvent('TodayView Appear'));
      verify(() => analytics.logScreenView(screenName: 'TodayView_Appear'))
          .called(1);
    });

    test('sets the user id but no name or email', () async {
      await service.identifyUser(userId: 'uid', name: 'A', email: 'a@b.c');
      verify(() => analytics.setUserId(id: 'uid')).called(1);
      verifyNever(
        () => analytics.setUserProperty(
          name: any(named: 'name'),
          value: any(named: 'value'),
        ),
      );
    });

    test('sets only high-priority user properties, as text', () async {
      await service.addUserProperties({'low': 1});
      await service.addUserProperties({
        'uauth_is_anonymous': false,
        'a_very_long_property_name_here': 'v w',
        'missing': null,
      }, isHighPriority: true);
      verify(
        () => analytics.setUserProperty(
          name: 'uauth_is_anonymous',
          value: 'false',
        ),
      ).called(1);
      verify(
        () => analytics.setUserProperty(
          name: 'a_very_long_property_nam',
          value: 'v_w',
        ),
      ).called(1);
      verifyNoMoreInteractions(analytics);
    });

    test('has no profile to delete', () async {
      await service.deleteUserProfile();
      verifyZeroInteractions(analytics);
    });
  });
}
