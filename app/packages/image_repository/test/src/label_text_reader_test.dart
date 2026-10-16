import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_repository/image_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(PlatformLabelTextReader.channelName);

  group('PlatformLabelTextReader', () {
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('sends the photo to the platform and trims its answer', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return '  Nutrition Facts\nProtein 13 g\n';
      });
      expect(
        await const PlatformLabelTextReader().read(jpeg),
        'Nutrition Facts\nProtein 13 g',
      );
      expect(calls.single.method, 'read');
      expect(calls.single.arguments, jpeg);
    });

    test('reads nothing as empty', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      expect(await const PlatformLabelTextReader().read(jpeg), isEmpty);
    });

    test('passes on a platform failure', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'unreadable'),
      );
      await expectLater(
        const PlatformLabelTextReader().read(jpeg),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('SampleLabelTextReader', () {
    test('reads every photo as the sample label', () async {
      expect(
        await const SampleLabelTextReader().read(jpeg),
        SampleLabelTextReader.sampleLabel,
      );
      expect(
        await const SampleLabelTextReader(text: 'Fat 1 g').read(jpeg),
        'Fat 1 g',
      );
    });
  });
}
