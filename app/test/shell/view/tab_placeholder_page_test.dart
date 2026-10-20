import 'package:compound/shell/shell.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(TabPlaceholderPage, () {
    for (final (tab, title) in [
      (AppTab.today, 'Today'),
      (AppTab.training, 'Training'),
      (AppTab.nutrition, 'Nutrition'),
      (AppTab.progress, 'Progress'),
      (AppTab.social, 'Social'),
    ]) {
      testWidgets('shows $title as coming soon', (tester) async {
        await tester.pumpApp(TabPlaceholderPage(tab: tab));

        expect(find.text(title), findsOneWidget);
        expect(find.text('Coming Soon'), findsOneWidget);
        expect(find.byIcon(tab.icon), findsOneWidget);
      });
    }
  });
}
