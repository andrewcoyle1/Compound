import 'package:analytics_repository/analytics_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixpanel_flutter/codec/mixpanel_message_codec.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:mocktail/mocktail.dart';

class _MockMixpanel extends Mock implements Mixpanel;

class _MockPeople extends Mock implements People;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(MixpanelService, () {
    late _MockMixpanel mixpanel;
    late _MockPeople people;
    late MixpanelService service;

    setUp(() {
      mixpanel = _MockMixpanel();
      people = _MockPeople();
      when(() => mixpanel.track(any(), properties: any(named: 'properties')))
          .thenAnswer((_) async {});
      when(() => mixpanel.identify(any())).thenAnswer((_) async {});
      when(() => mixpanel.getPeople()).thenReturn(people);
      service = MixpanelService(mixpanel: mixpanel);
    });

    test('starts on the EU servers with the build configuration', () async {
      const channel = MethodChannel(
        'mixpanel_flutter',
        StandardMethodCodec(MixpanelMessageCodec()),
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return null;
            });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await MixpanelService.init(token: 'token', buildConfiguration: 'dev');

      final arguments = calls.single.arguments as Map<Object?, Object?>;
      expect(calls.single.method, 'initialize');
      expect(arguments['token'], 'token');
      expect(arguments['trackAutomaticEvents'], isTrue);
      expect(arguments['serverURL'], 'https://api-eu.mixpanel.com');
      expect(arguments['superProperties'], {'build_configuration': 'dev'});
    });

    test('tracks events and screen views with clean properties', () async {
      await service.trackEvent(
        const AnalyticsEvent('E', parameters: {'a': 1, 'b': null}),
      );
      await service.trackScreenView(const AnalyticsEvent('TodayView_Appear'));
      verify(() => mixpanel.track('E', properties: {'a': 1})).called(1);
      verify(() => mixpanel.track('TodayView_Appear')).called(1);
    });

    test('identifies the user with their name and email', () async {
      await service.identifyUser(userId: 'uid', name: 'Alice', email: 'a@b.c');
      await service.identifyUser(userId: 'anon');
      verify(() => mixpanel.identify('uid')).called(1);
      verify(() => mixpanel.identify('anon')).called(1);
      verify(() => people.set(r'$name', 'Alice')).called(1);
      verify(() => people.set(r'$email', 'a@b.c')).called(1);
      verifyNoMoreInteractions(people);
    });

    test('sets every user property', () async {
      await service.addUserProperties({'a': 1, 'b': Object()});
      verify(() => people.set('a', 1)).called(1);
      verifyNoMoreInteractions(people);
    });

    test('deletes the user profile', () async {
      await service.deleteUserProfile();
      verify(people.deleteUser).called(1);
    });
  });
}
