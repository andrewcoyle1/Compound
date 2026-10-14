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
}
