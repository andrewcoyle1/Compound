import 'package:analytics_repository/analytics_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService;

void main() {
  const event = AnalyticsEvent('TodayView_Appear');

  setUpAll(() => registerFallbackValue(event));

  group(AnalyticsRepository, () {
    late _MockAnalyticsService first;
    late _MockAnalyticsService second;
    late AnalyticsRepository repository;

    setUp(() {
      first = _MockAnalyticsService();
      second = _MockAnalyticsService();
      for (final service in [first, second]) {
        when(() => service.trackEvent(any())).thenAnswer((_) async {});
        when(() => service.trackScreenView(any())).thenAnswer((_) async {});
        when(
          () => service.identifyUser(
            userId: any(named: 'userId'),
            name: any(named: 'name'),
            email: any(named: 'email'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => service.addUserProperties(
            any(),
            isHighPriority: any(named: 'isHighPriority'),
          ),
        ).thenAnswer((_) async {});
        when(service.deleteUserProfile).thenAnswer((_) async {});
      }
      repository = AnalyticsRepository(services: [first, second]);
    });

    test('does nothing without services', () {
      const AnalyticsRepository()
        ..trackEvent(event)
        ..trackScreenView(event)
        ..identifyUser(userId: 'uid')
        ..addUserProperties({})
        ..deleteUserProfile();
    });

    test('sends events to every service', () {
      repository.trackEvent(event);
      verify(() => first.trackEvent(event)).called(1);
      verify(() => second.trackEvent(event)).called(1);
    });

    test('sends screen views to every service', () {
      repository.trackScreenView(event);
      verify(() => first.trackScreenView(event)).called(1);
      verify(() => second.trackScreenView(event)).called(1);
    });

    test('identifies the user to every service', () {
      repository.identifyUser(userId: 'uid', name: 'Alice', email: 'a@b.c');
      for (final service in [first, second]) {
        verify(
          () => service.identifyUser(
            userId: 'uid',
            name: 'Alice',
            email: 'a@b.c',
          ),
        ).called(1);
      }
    });

    test('adds user properties at every service', () {
      repository
        ..addUserProperties({'a': 1})
        ..addUserProperties({'b': 2}, isHighPriority: true);
      for (final service in [first, second]) {
        verify(() => service.addUserProperties({'a': 1})).called(1);
        verify(() => service.addUserProperties({'b': 2}, isHighPriority: true))
            .called(1);
      }
    });

    test('deletes the user profile at every service', () {
      repository.deleteUserProfile();
      verify(first.deleteUserProfile).called(1);
      verify(second.deleteUserProfile).called(1);
    });

    test('carries on past a service that throws or fails', () async {
      when(() => first.trackEvent(any())).thenThrow(StateError('sync'));
      when(() => second.trackScreenView(any()))
          .thenAnswer((_) => Future.error(StateError('async')));

      repository
        ..trackEvent(event)
        ..trackScreenView(event);
      await pumpEventQueue();

      verify(() => second.trackEvent(event)).called(1);
      verify(() => first.trackScreenView(event)).called(1);
    });
  });

  group(AnalyticsEvent, () {
    test('is an analytic event without parameters by default', () {
      expect(event.eventName, 'TodayView_Appear');
      expect(event.parameters, isNull);
      expect(event.type, LogType.analytic);
    });
  });
}
