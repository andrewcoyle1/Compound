import 'package:flutter_test/flutter_test.dart';
import 'package:health_repository/src/days.dart';
import 'package:health_repository/src/import_rules.dart';

void main() {
  test('healthUuid keeps only UUIDs, upper case', () {
    expect(
      healthUuid('a1b2c3d4-0000-4000-8000-00000000000f'),
      'A1B2C3D4-0000-4000-8000-00000000000F',
    );
    expect(healthUuid(''), isNull);
    expect(healthUuid('record-1'), isNull);
  });

  test('dayKeyOf writes yyyy-MM-dd on the local calendar', () {
    expect(dayKeyOf(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
  });

  test('nextDay is the next midnight across a clock change', () {
    expect(nextDay(DateTime(2026, 3, 28)), DateTime(2026, 3, 29));
    expect(startOfDay(DateTime(2026, 3, 29, 15)), DateTime(2026, 3, 29));
  });
}
