import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shown while the signed-in user's profile loads (or, for a new account,
/// is written), and when it can't be read: then with Try Again and Sign Out.
class LaunchPage extends StatelessWidget {
  const new({super.key});

  static const path = '/launch';
  static const name = 'launch';

  /// The query parameter carrying where the user was going.
  static const fromParameter = 'from';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AppBloc>().state;
    final failed =
        state is AppAuthenticated &&
        state.profileStatus == AppProfileStatus.failure;
    return AppScaffold(
      body: SafeArea(
        child: Center(
          child: failed
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppSpacing.l,
                    children: [
                      Text(
                        l10n.launchProfileFailure,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.rowTitle,
                      ),
                      AppCtaButton(
                        label: l10n.tryAgainButton,
                        onPressed: () => context.read<AppBloc>().add(
                          const AppProfileRetryRequested(),
                        ),
                      ),
                      AppCtaButton(
                        label: l10n.signOutButton,
                        variant: AppCtaVariant.plain,
                        onPressed: () => context.read<AppBloc>().add(
                          const AppSignOutPressed(),
                        ),
                      ),
                    ],
                  ),
                )
              : Semantics(
                  label: l10n.launchLoading,
                  child: const CircularProgressIndicator.adaptive(),
                ),
        ),
      ),
    );
  }
}
