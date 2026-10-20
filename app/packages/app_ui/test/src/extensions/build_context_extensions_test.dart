import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  testWidgets('appColors reads the theme extension', (tester) async {
    late AppColors colors;
    await tester.pumpApp(
      Builder(
        builder: (context) {
          colors = context.appColors;
          return const SizedBox();
        },
      ),
      theme: AppTheme.dark,
    );
    expect(colors, same(AppColors.dark));
  });

  group('isRegularWidth', () {
    Future<bool> regularAt(WidgetTester tester, Size size) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late bool regular;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            regular = context.isRegularWidth;
            return const SizedBox();
          },
        ),
      );
      return regular;
    }

    testWidgets('is false on a phone', (tester) async {
      expect(await regularAt(tester, const Size(390, 844)), isFalse);
    });

    testWidgets('is true on an iPad', (tester) async {
      expect(await regularAt(tester, const Size(820, 1180)), isTrue);
    });
  });
}
