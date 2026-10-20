import 'package:app_ui/app_ui.dart';
import 'package:compound/profile/profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(ProfileButton, () {
    testWidgets('shows the signed-in user’s photo', (tester) async {
      final world = (await tester.runAsync(SocialWorld.create))!;
      await tester.pumpApp(
        const ProfileButton(),
        userRepository: world.users,
        workoutSessionRepository: world.sessions,
        socialRepository: world.social,
        circleBloc: world.circle,
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, const NetworkImage('https://picsum.photos/200'));
      expect(find.byTooltip('Profile'), findsOneWidget);
    });

    testWidgets('shows the profile glyph before anyone signs in', (
      tester,
    ) async {
      await tester.pumpApp(const ProfileButton());
      expect(find.byIcon(AppSymbols.profile), findsOneWidget);
    });
  });
}
