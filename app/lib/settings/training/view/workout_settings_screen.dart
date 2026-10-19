import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/training/cubit/workout_settings_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// Applies a change to the workout settings: keys from
/// [WorkoutSettingsKeys], null clearing an optional one.
typedef WorkoutSettingsChange = void Function(Map<String, Object?> fields);

/// The frame every workout-settings screen shares: its own
/// [WorkoutSettingsCubit] under the Swift screen name [screen], the title,
/// the sections [sections] builds once the settings are read, and a snack
/// bar when a save fails.
class WorkoutSettingsScreen extends StatelessWidget {
  const new({
    required this.screen,
    required this.title,
    required this.sections,
    super.key,
  });

  /// The Swift view's name, for analytics: `RestTimerSettingsView`.
  final String screen;
  final String title;
  final List<Widget> Function(
    BuildContext context,
    WorkoutSettings settings,
    WorkoutSettingsChange change,
  )
  sections;

  @override
  Widget build(BuildContext context) {
    // The router only shows settings while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) =>
          WorkoutSettingsCubit(
              repository: context.read<TrainingLibraryRepository>(),
              analytics: context.read<AnalyticsRepository>(),
              uid: state.user.uid,
              screen: screen,
            )
            ..subscribe()
            ..appeared(),
      child: _WorkoutSettingsView(title: title, sections: sections),
    );
  }
}

class _WorkoutSettingsView extends StatefulWidget {
  const new({required this.title, required this.sections});

  final String title;
  final List<Widget> Function(
    BuildContext context,
    WorkoutSettings settings,
    WorkoutSettingsChange change,
  )
  sections;

  @override
  State<_WorkoutSettingsView> createState() => _WorkoutSettingsViewState();
}

class _WorkoutSettingsViewState extends State<_WorkoutSettingsView> {
  late final WorkoutSettingsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<WorkoutSettingsCubit>();
  }

  @override
  void dispose() {
    _cubit.disappeared();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.select<WorkoutSettingsCubit, WorkoutSettings?>(
      (cubit) => cubit.state.settings,
    );
    return BlocListener<WorkoutSettingsCubit, WorkoutSettingsState>(
      listenWhen: (previous, current) =>
          current.saveFailed && !previous.saveFailed,
      listener: (context, _) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.workoutSettingsSaveFailed)),
        ),
      child: AppScaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: settings == null
            ? AppLoadingView(label: context.l10n.launchLoading)
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  children: [
                    for (final (index, section)
                        in widget
                            .sections(context, settings, _cubit.change)
                            .indexed) ...[
                      if (index > 0) const SizedBox(height: AppSpacing.xl),
                      section,
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// A row whose value is picked from a menu, as Swift's menu `Picker`.
class SettingsMenuRow<T> extends StatelessWidget {
  const new({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon,
    super.key,
  });

  final String title;
  final IconData? icon;
  final T value;

  /// Each option and its name, in order.
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = options.firstWhere((option) => option.$1 == value).$2;
    return MenuAnchor(
      menuChildren: [
        for (final (option, name) in options)
          MenuItemButton(
            leadingIcon: Icon(
              AppSymbols.selected,
              color: option == value ? null : Colors.transparent,
            ),
            onPressed: () => onChanged(option),
            child: Semantics(selected: option == value, child: Text(name)),
          ),
      ],
      builder: (context, controller, _) => AppListRowButton(
        title: title,
        icon: icon,
        accessory: AppListRowMenu(current),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
