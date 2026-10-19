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
import 'package:compound/widgets/number_wheel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:user_repository/user_repository.dart';

/// Log Measurement (Swift `LogMeasurementView`): one view for all eighteen
/// circumferences, driven by [kind]: the day, the unit, and the reading on
/// a whole-number wheel and a tenths wheel. Opened over the tabs.
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

class LogMeasurementView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<LogMeasurementBloc>().state;
    return BlocListener<LogMeasurementBloc, LogMeasurementState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case LogMeasurementStatus.saved:
            unawaited(HapticFeedback.successNotification());
            _dismiss(context);
          case LogMeasurementStatus.failure:
            unawaited(HapticFeedback.errorNotification());
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
              onPressed: state.isEditable
                  ? () => context.read<LogMeasurementBloc>().add(
                      const LogMeasurementSaveRequested(),
                    )
                  : null,
            ),
          ],
        ),
        body: state.status == LogMeasurementStatus.loading
            ? AppLoadingView(label: l10n.launchLoading)
            : _Form(state: state),
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
  const new({required this.state});

  final LogMeasurementState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<LogMeasurementBloc>();
    final scaler = MediaQuery.textScalerOf(context);
    final metric = state.unit == LengthUnitPreference.centimeters;
    final range = metric ? state.kind.centimetres : state.kind.inches;
    final label = l10n.measurementCircumference(
      bodyMeasurementName(l10n, state.kind),
    );
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
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          label: l10n.logWeightUnits,
          container: true,
          child: AppSegmentedControl<LengthUnitPreference>(
            segments: [
              AppSegment(
                value: LengthUnitPreference.centimeters,
                label: l10n.logMeasurementMetric,
              ),
              AppSegment(
                value: LengthUnitPreference.inches,
                label: l10n.logMeasurementImperial,
              ),
            ],
            selected: state.unit,
            onChanged: (unit) => bloc.add(LogMeasurementUnitChanged(unit)),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSection(
          header: label,
          children: [
            // About five rows, growing with the text so none is clipped.
            SizedBox(
              height: scaler.scale(150),
              child: Row(
                // Keyed by unit, so switching unit builds wheels that open
                // on the other unit's values.
                key: ValueKey(state.unit),
                children: [
                  Expanded(
                    child: NumberWheel(
                      label: label,
                      values: [for (var v = range.min; v <= range.max; v++) v],
                      selected: metric ? state.centimetres : state.inches,
                      itemLabel: metric
                          ? l10n.logMeasurementWholeCentimetres
                          : l10n.logMeasurementWholeInches,
                      onChanged: (whole) =>
                          bloc.add(LogMeasurementWholeChanged(whole)),
                    ),
                  ),
                  Expanded(
                    child: NumberWheel(
                      label: l10n.logWeightTenths,
                      values: DecimalWheelValue.tenths,
                      selected: metric
                          ? state.centimetresTenths
                          : state.inchesTenths,
                      itemLabel: l10n.logWeightTenthsValue,
                      onChanged: (tenths) =>
                          bloc.add(LogMeasurementTenthsChanged(tenths)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
