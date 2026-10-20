import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/first_weekday.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

void main() {
  group('firstDayOfWeekIndexIn', () {
    test("follows CLDR's week data by region", () {
      expect(firstDayOfWeekIndexIn('US'), 0);
      expect(firstDayOfWeekIndexIn('gb'), DateTime.monday);
      expect(firstDayOfWeekIndexIn('ES'), DateTime.monday);
      expect(firstDayOfWeekIndexIn('MX'), 0);
      expect(firstDayOfWeekIndexIn('AE'), DateTime.saturday);
      expect(firstDayOfWeekIndexIn('MV'), DateTime.friday);
    });
  });

  group('firstDayOfWeekIndex', () {
    Future<int> read(WidgetTester tester, Locale device) async {
      tester.platformDispatcher.localeTestValue = device;
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      late int index;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            index = firstDayOfWeekIndex(context);
            return const SizedBox();
          },
        ),
      );
      return index;
    }

    testWidgets('a British English device starts on Monday', (tester) async {
      expect(await read(tester, const Locale('en', 'GB')), DateTime.monday);
    });

    testWidgets('an American one on Sunday', (tester) async {
      expect(await read(tester, const Locale('en', 'US')), 0);
    });

    testWidgets("without a region, the language's day", (tester) async {
      expect(await read(tester, const Locale('en')), 0);
    });
  });
}
