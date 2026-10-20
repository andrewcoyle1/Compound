import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every screen is an `AppScaffold`, so its app bar spans the window and its
/// content sits in the readable column. Only the tab bar's page, which
/// spans the window, is a bare `Scaffold`.
void main() {
  test('no screen uses a bare Scaffold', () {
    final bare = RegExp(r'(?<![\w.])Scaffold\(');
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            !file.path.endsWith('app_shell.dart') &&
            bare.hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty);
  });
}
