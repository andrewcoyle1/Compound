import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/general/cubit/screen_tracking_cubit.dart';
import 'package:compound/settings/general/view/on_dispose.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The open-source licences (Swift `LicencesView`): Flutter's own licence
/// page, which lists every package registered with `LicenseRegistry`, under
/// Swift's thank-you.
class LicencesPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'licences';
  static const name = 'settingsLicences';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ScreenTrackingCubit(
        analytics: context.read<AnalyticsRepository>(),
        screen: 'LicencesView',
      )..appeared(),
      child: Builder(
        builder: (context) => OnDispose(
          onDispose: context.read<ScreenTrackingCubit>().disappeared,
          child: LicensePage(
            applicationName: 'Compound',
            applicationLegalese: context.l10n.licencesIntro,
          ),
        ),
      ),
    );
  }
}
