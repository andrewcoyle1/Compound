import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _plugin = MethodChannel('haptic_feedback');

final _all = <Future<void> Function()>[
  AppHaptics.success,
  AppHaptics.error,
  AppHaptics.warning,
  AppHaptics.selection,
  AppHaptics.light,
  AppHaptics.medium,
  AppHaptics.heavy,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> pluginCalls;
  late List<Object?> flutterHaptics;

  void plugin({required bool canVibrate}) =>
      messenger.setMockMethodCallHandler(_plugin, (call) async {
        pluginCalls.add(call);
        return call.method == 'canVibrate' ? canVibrate : null;
      });

  setUp(() {
    AppHaptics.debugReset();
    pluginCalls = [];
    flutterHaptics = [];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        flutterHaptics.add(call.arguments);
      }
      return null;
    });
  });

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(_plugin, null)
      ..setMockMethodCallHandler(SystemChannels.platform, null);
    AppHaptics.debugPlay = null;
  });

  group('AppHaptics', () {
    test('plays the iOS patterns through haptic_feedback, '
        'asking once whether the device can vibrate', () async {
      plugin(canVibrate: true);
      for (final haptic in _all) {
        await haptic();
      }
      expect(pluginCalls.map((c) => c.method), [
        'canVibrate',
        'success',
        'error',
        'warning',
        'selection',
        'light',
        'medium',
        'heavy',
      ]);
      expect(
        pluginCalls.skip(1).map((c) => (c.arguments as Map)['usage']),
        everyElement('touch'),
      );
      expect(flutterHaptics, isEmpty);
    });

    test("falls back to Flutter's haptics without a vibrator", () async {
      plugin(canVibrate: false);
      for (final haptic in _all) {
        await haptic();
      }
      expect(pluginCalls.map((c) => c.method), ['canVibrate']);
      expect(flutterHaptics, [
        'HapticFeedbackType.successNotification',
        'HapticFeedbackType.errorNotification',
        'HapticFeedbackType.warningNotification',
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });

    test("falls back to Flutter's haptics without the plugin", () async {
      await AppHaptics.success();
      expect(flutterHaptics, ['HapticFeedbackType.successNotification']);
    });

    test('hands each haptic to debugPlay instead of the device', () async {
      plugin(canVibrate: true);
      final played = <AppHaptic>[];
      AppHaptics.debugPlay = played.add;
      for (final haptic in _all) {
        await haptic();
      }
      expect(played, AppHaptic.values);
      expect(pluginCalls, isEmpty);
      expect(flutterHaptics, isEmpty);
    });
  });
}
