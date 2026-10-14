import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/profile/view/profile_page.dart';
import 'package:go_router/go_router.dart';

/// The profile button at the trailing end of every tab's app bar, as in the
/// Swift app. Opens the user's own profile over the tabs.
class ProfileButton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(AppSymbols.profile),
      tooltip: context.l10n.profileTitle,
      onPressed: () => context.pushNamed(ProfilePage.name),
    );
  }
}
