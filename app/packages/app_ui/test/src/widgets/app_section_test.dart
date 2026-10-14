import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppSection', () {
    testWidgets('puts rows on a card with dividers between', (tester) async {
      await tester.pumpApp(
        const AppSection(
          header: 'Goal',
          footer: 'Change it any time.',
          children: [
            AppListRow(title: 'One'),
            AppListRow(title: 'Two'),
            AppListRow(title: 'Three'),
          ],
        ),
      );
      expect(find.byType(AppCard), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
      expect(find.text('Change it any time.'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Goal')),
        isSemantics(label: 'Goal', isHeader: true),
      );
    });

    testWidgets('header and footer are optional', (tester) async {
      await tester.pumpApp(
        const AppSection(children: [AppListRow(title: 'One')]),
      );
      expect(find.byType(Divider), findsNothing);
      expect(find.byType(Text), findsOneWidget);
    });
  });
}
