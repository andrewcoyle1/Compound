import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/profile/social_profile_page.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The signed-in user's own profile, opened over the tabs from the
/// [ProfileButton](package:compound/profile/view/profile_button.dart): the
/// Swift app's `SocialProfileView` for the reader, with a close button,
/// Settings and Edit Profile.
class ProfilePage extends StatelessWidget {
  const new({super.key});

  static const path = '/profile';
  static const name = 'profile';

  @override
  Widget build(BuildContext context) {
    // The router only shows this page while someone is signed in.
    final viewer = context.select<CircleBloc, UserModel?>(
      (bloc) => bloc.state.viewer,
    );
    if (viewer == null) return const SizedBox.shrink();
    return SocialProfilePage(
      key: ValueKey(viewer.userId),
      userId: viewer.userId,
      user: viewer,
      isPresentedModally: true,
    );
  }
}
