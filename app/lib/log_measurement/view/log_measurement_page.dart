import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_measurement/bloc/log_measurement_bloc.dart';
import 'package:compound/log_weight/logic/decimal_wheel_value.dart';
import 'package:compound/progress/logic/body_metrics.dart';
import 'package:compound/progress/view/progress_names.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:user_repository/user_repository.dart';

/// Log Measurement (Swift `LogMeasurementView`): one view for all eighteen
/// circumferences, driven by [kind]: the day, and the reading typed with
/// its unit, kept to the span Swift's wheels offered. Opened over the tabs.
class LogMeasurementPage extends StatelessWidget {
  const new({required this.kind, super.key});

  /// The route's path and name.
  static const path = '/log-measurement/:$kindParameter';
  static const name = 'logMeasurement';

  /// The circumference's path parameter: its raw value.
  static const kindParameter = 'kind';

  /// Opens the logger for [kind].
  static Future<void> show(BuildContext context, BodyMeasurementKind kind) =>
      context.pushNamed<void>(name, pathParameters: {kindParameter: kind.name});

  /// Which circumference.
  final BodyMeasurementKind kind;

  @override
  Widget build(BuildContext context) {
    // The router only shows this page while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => LogMeasurementBloc(
        bodyRepository: context.read<BodyRepository>(),
        userRepository: context.read<UserRepository>(),
        analyticsRepository: context.read<AnalyticsRepository>(),
        uid: state.user.uid,
        kind: kind,
      )..add(const LogMeasurementStarted()),
      child: const LogMeasurementView(),
    );
  }
}

class LogMeasurementView extends StatefulWidget {
  const new({super.key});

  @override
  State<LogMeasurementView> createState() => _LogMeasurementViewState();
}

class _LogMeasurementViewState extends State<LogMeasurementView> {
  /// Whether anything has been typed: until then the field shows the
  /// bloc's reading.
  var _edited = false;

  /// What was typed; null when it does not read as a number.
  double? _typed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<LogMeasurementBloc>().state;
    final bloc = context.read<LogMeasurementBloc>();
    final metric = state.unit == LengthUnitPreference.centimeters;
    final range = metric ? state.kind.centimetres : state.kind.inches;
    final reading = _edited
        ? _typed
        : metric
        ? DecimalWheelValue.combine(
            whole: state.centimetres,
            tenths: state.centimetresTenths,
          )
        : DecimalWheelValue.combine(
            whole: state.inches,
            tenths: state.inchesTenths,
          );
    // Kept to the span the wheels offered.
    bool inRange(double? value) =>
        value != null && value >= range.min && value < range.max + 1;
    return BlocListener<LogMeasurementBloc, LogMeasurementState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case LogMeasurementStatus.saved:
            unawaited(AppHaptics.success());
            _dismiss(context);
          case LogMeasurementStatus.failure:
            unawaited(AppHaptics.error());
            unawaited(
              showAppDialog<void>(
                context: context,
                title: context.l10n.logMeasurementSaveFailure,
                actions: [
                  AppDialogAction(
                    label: MaterialLocalizations.of(context).okButtonLabel,
                    role: AppDialogRole.preferred,
                  ),
                ],
              ),
            );
          case LogMeasurementStatus.loading ||
              LogMeasurementStatus.ready ||
              LogMeasurementStatus.saving:
            break;
        }
      },
      child: AppScaffold(
        appBar: AppBar(
          leading: AppToolbarButton.close(
            semanticLabel: MaterialLocalizations.of(context).closeButtonLabel,
            onPressed: () => _dismiss(context),
          ),
          title: Text(
            l10n.logMeasurementTitle(bodyMeasurementName(l10n, state.kind)),
          ),
          actions: [
            AppToolbarButton.confirm(
              semanticLabel: l10n.logWeightSave,
              isSaving: state.status == LogMeasurementStatus.saving,
              onPressed: state.isEditable && inRange(reading)
                  ? () => bloc.add(const LogMeasurementSaveRequested())
                  : null,
            ),
          ],
        ),
        body: state.status == LogMeasurementStatus.loading
            ? AppLoadingView(label: l10n.launchLoading)
            : _Form(
                state: state,
                reading: reading,
                onReadingChanged: (value) {
                  setState(() {
                    _edited = true;
                    _typed = value;
                  });
                  if (!inRange(value)) return;
                  final (:whole, :tenths) = DecimalWheelValue.split(value!);
                  bloc
                    ..add(LogMeasurementWholeChanged(whole))
                    ..add(LogMeasurementTenthsChanged(tenths));
                },
                onUnitChanged: (unit) {
                  setState(() => _edited = false);
                  bloc.add(LogMeasurementUnitChanged(unit));
                },
              ),
      ),
    );
  }

  /// Back to wherever it was opened from; to Progress when opened directly.
  static void _dismiss(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppTab.progress.path);
    }
  }
}

class _Form extends StatelessWidget {
  const new({
    required this.state,
    required this.reading,
    required this.onReadingChanged,
    required this.onUnitChanged,
  });

  final LogMeasurementState state;
  final double? reading;
  final ValueChanged<double?> onReadingChanged;
  final ValueChanged<LengthUnitPreference> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<LogMeasurementBloc>();
    // Unit symbols read the same in every language.
    const units = {
      LengthUnitPreference.centimeters: 'cm',
      LengthUnitPreference.inches: 'in',
    };
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        AppSection(
          children: [
            AppListRowButton(
              title: l10n.logWeightDate,
              accessory: AppListRowValue(
                AppFormat.date(state.date, locale: context.dateLocale),
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: state.date,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null) bloc.add(LogMeasurementDateChanged(picked));
              },
            ),
            AppNumberField.units(
              key: const Key('LogMeasurement.reading'),
              label: l10n.measurementCircumference(
                bodyMeasurementName(l10n, state.kind),
              ),
              value: reading,
              prompt: '0',
              unit: units[state.unit]!,
              units: units.values.toList(),
              unitsLabel: l10n.logWeightUnits,
              onUnitChanged: (symbol) => onUnitChanged(
                units.entries.firstWhere((e) => e.value == symbol).key,
              ),
              onChanged: onReadingChanged,
            ),
          ],
        ),
      ],
    );
  }
}
