import 'package:app_ui/app_ui.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/training/training.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(TrainingPage, () {
    testWidgets('offers the workout history from the Library', (tester) async {
      await tester.pumpApp(const TrainingPage());
      await tester.pump();

      expect(find.widgetWithText(AppBar, 'Training'), findsOneWidget);
      expect(find.byType(ProfileButton), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Workout History'), findsOneWidget);
    });
  });
}
