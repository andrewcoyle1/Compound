import 'package:analytics_repository/analytics_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ConsoleService, () {
    late List<(String, LogType)> lines;
    late ConsoleService service;

    setUp(() {
      lines = [];
      service = ConsoleService(
        log: (message, type) => lines.add((message, type)),
      );
    });

    test('prints an event with its parameters sorted by key', () async {
      await service.trackEvent(
        const AnalyticsEvent(
          'SaveFail',
          parameters: {'b': 2, 'a': 'x'},
          type: LogType.severe,
        ),
      );
      expect(lines, [
        (
          '🚨 SaveFail\n    (key: "a", value: x)\n    (key: "b", value: 2)',
          LogType.severe,
        ),
      ]);
    });

    test('prints a screen view as an event', () async {
      await service.trackScreenView(const AnalyticsEvent('TodayView_Appear'));
      expect(lines, [('📈 TodayView_Appear', LogType.analytic)]);
    });

    test('prints the user it identifies', () async {
      await service.identifyUser(userId: 'uid', name: 'Alice');
      expect(lines, [
        (
          '📈 Identify User\n    - userId: uid\n    - name: Alice\n'
              '    - email: null',
          LogType.info,
        ),
      ]);
    });

    test('prints user properties', () async {
      await service.addUserProperties({'z': true}, isHighPriority: true);
      expect(lines, [
        (
          '📈 Add User Properties: (isHighPriority: true)\n'
              '    (key: "z", value: true)',
          LogType.info,
        ),
      ]);
    });

    test('prints a profile deletion', () async {
      await service.deleteUserProfile();
      expect(lines, [('📈 Delete User Profile', LogType.info)]);
    });

    test('leaves out parameters and names when asked', () async {
      service = ConsoleService(
        printParameters: false,
        log: (message, type) => lines.add((message, type)),
      );
      await service.trackEvent(
        const AnalyticsEvent('E', parameters: {'a': 1}, type: LogType.info),
      );
      await service.identifyUser(userId: 'uid', name: 'Alice');
      await service.addUserProperties({'a': 1});
      expect(lines.map((line) => line.$1), [
        '👋 E',
        '📈 Identify User\n    - userId: uid',
        '📈 Add User Properties: (isHighPriority: false)',
      ]);
    });

    test('writes to the developer log by default', () async {
      await const ConsoleService().trackEvent(
        const AnalyticsEvent('E', type: LogType.warning),
      );
    });
  });
}
