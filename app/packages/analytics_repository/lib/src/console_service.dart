import 'dart:developer' as developer;

import 'package:analytics_repository/analytics_repository.dart';
import 'package:flutter/foundation.dart';

/// Writes a line of console output at a [LogType]'s level.
typedef ConsoleLog = void Function(String message, LogType type);

void _developerLog(String message, LogType type) =>
    developer.log(message, name: 'analytics', level: type.level);

/// {@template console_service}
/// Prints every call to the debug console, in the Swift `ConsoleService`'s
/// format. The staging flavor's only service.
/// {@endtemplate}
class ConsoleService implements AnalyticsService {
  /// {@macro console_service}
  const new({
    this.printParameters = true,
    @visibleForTesting this._log = _developerLog,
  });

  /// Whether parameters, names and emails are printed too.
  final bool printParameters;

  final ConsoleLog _log;

  @override
  Future<void> trackEvent(LoggableEvent event) async {
    final buffer = StringBuffer('${event.type.emoji} ${event.eventName}');
    if (printParameters) _writeSorted(buffer, event.parameters ?? const {});
    _log(buffer.toString(), event.type);
  }

  @override
  Future<void> trackScreenView(LoggableEvent event) => trackEvent(event);

  @override
  Future<void> identifyUser({
    required String userId,
    String? name,
    String? email,
  }) async {
    final buffer = StringBuffer('📈 Identify User\n    - userId: $userId');
    if (printParameters) {
      buffer.write('\n    - name: $name\n    - email: $email');
    }
    _log(buffer.toString(), LogType.info);
  }

  @override
  Future<void> addUserProperties(
    Map<String, Object?> properties, {
    bool isHighPriority = false,
  }) async {
    final buffer = StringBuffer(
      '📈 Add User Properties: (isHighPriority: $isHighPriority)',
    );
    if (printParameters) _writeSorted(buffer, properties);
    _log(buffer.toString(), LogType.info);
  }

  @override
  Future<void> deleteUserProfile() async =>
      _log('📈 Delete User Profile', LogType.info);

  void _writeSorted(StringBuffer buffer, Map<String, Object?> values) {
    for (final key in values.keys.toList()..sort()) {
      buffer.write('\n    (key: "$key", value: ${values[key]})');
    }
  }
}
