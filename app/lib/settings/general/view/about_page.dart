import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app_version.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/general/cubit/screen_tracking_cubit.dart';
import 'package:compound/settings/general/view/licences_page.dart';
import 'package:compound/settings/general/view/on_dispose.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// What Compound is, the version and build installed, and the way to the
/// licences (Swift `AboutView`).
class AboutPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'about';
  static const name = 'settingsAbout';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ScreenTrackingCubit(
        analytics: context.read<AnalyticsRepository>(),
        screen: 'AboutView',
      )..appeared(),
      child: const AboutView(),
    );
  }
}

class AboutView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final version = context.read<AppVersion?>();
    return OnDispose(
      onDispose: context.read<ScreenTrackingCubit>().disappeared,
      child: AppScaffold(
        appBar: AppBar(title: Text(l10n.aboutTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              Text(
                version == null
                    ? l10n.aboutBody
                    : l10n.aboutBodyVersion(version.version, version.build),
                style: AppTextStyles.rowTitle,
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomCta(
          children: [
            AppCtaButton(
              label: l10n.aboutViewLicences,
              variant: AppCtaVariant.secondary,
              onPressed: () => context.pushNamed(LicencesPage.name),
            ),
          ],
        ),
      ),
    );
  }
}
