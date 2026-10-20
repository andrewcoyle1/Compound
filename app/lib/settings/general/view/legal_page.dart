import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/general/cubit/screen_tracking_cubit.dart';
import 'package:compound/settings/general/view/on_dispose.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The agreements (Swift `LegalView`). Swift links each to an address that
/// is still a placeholder; with no published documents and no way to open
/// links yet, each row is a plain title and the footer says why.
class LegalPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'legal';
  static const name = 'settingsLegal';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ScreenTrackingCubit(
        analytics: context.read<AnalyticsRepository>(),
        screen: 'LegalView',
      )..appeared(),
      child: const LegalView(),
    );
  }
}

class LegalView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OnDispose(
      onDispose: context.read<ScreenTrackingCubit>().disappeared,
      child: AppScaffold(
        appBar: AppBar(title: Text(l10n.settingsLegal)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              AppSection(
                header: l10n.legalAgreementsHeader,
                footer: l10n.legalNotPublished,
                children: [
                  for (final title in [
                    l10n.legalTermsOfService,
                    l10n.legalPrivacyPolicy,
                    l10n.legalHealthDisclaimer,
                    l10n.legalConsumerHealthPrivacy,
                  ])
                    AppListRow(title: title),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
