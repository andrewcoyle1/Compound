import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Widget tests time out after 30 seconds instead of Flutter's 10 minutes.
///
/// `testWidgets` passes the binding's default timeout explicitly, so
/// `--timeout` on the command line does not shorten it. A test that awaits
/// something only a pump can complete sits idle until the timeout; with 10
/// minutes per test, a few such tests stalled a whole run for half an hour.
/// The full suite takes about 25 seconds, so 30 per test is generous.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  if (binding is AutomatedTestWidgetsFlutterBinding) {
    binding.defaultTestTimeout = const Timeout(Duration(seconds: 30));
  }
  await testMain();
}
