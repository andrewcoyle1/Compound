import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/profile/view/profile_page.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_repository/social_repository.dart';

/// The profile button at the trailing end of every tab's app bar, as in the
/// Swift app: the user's photo, else their initials, else the profile glyph.
/// Opens the user's own profile over the tabs.
class ProfileButton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final viewer = context.select<CircleBloc, UserModel?>(
      (bloc) => bloc.state.viewer,
    );
    final photo = viewer == null ? null : profileImageOf(viewer);
    final name = viewer == null ? null : fullNameOf(viewer);
    return AppToolbarButton.avatar(
      semanticLabel: context.l10n.profileTitle,
      onPressed: () => context.pushNamed(ProfilePage.name),
      image: photo == null || photo.isEmpty ? null : storedImageProvider(photo),
      initials: name
          ?.split(' ')
          .where((word) => word.isNotEmpty)
          .take(2)
          .map((word) => word.characters.first.toUpperCase())
          .join(),
    );
  }
}
