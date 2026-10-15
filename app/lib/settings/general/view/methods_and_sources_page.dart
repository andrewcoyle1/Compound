import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/settings/general/cubit/screen_tracking_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Every calculation the app explains with an info button, each opening the
/// same sheet (Swift `MethodsAndSourcesView`).
class MethodsAndSourcesPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'methods';
  static const name = 'settingsMethods';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ScreenTrackingCubit(
        analytics: context.read<AnalyticsRepository>(),
        screen: 'MethodsAndSourcesView',
      )..appeared(),
      child: const MethodsAndSourcesView(),
    );
  }
}

class MethodsAndSourcesView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsMethodsAndSources)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            AppSection(
              footer: l10n.methodsAndSourcesFooter,
              children: [
                for (final MapEntry(key: id, value: info) in MethodInfo.all(
                  l10n,
                ).entries)
                  AppListRowButton(
                    title: info.title,
                    onPressed: () => _open(context, id, info),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void _open(BuildContext context, String id, MethodInfo info) {
    context.read<ScreenTrackingCubit>().pressed('Method_Press', {'method': id});
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) =>
            MethodInfoSheet(info: info, controller: controller),
      ),
    );
  }
}
