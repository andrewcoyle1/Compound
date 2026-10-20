import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_weight/bloc/log_weight_bloc.dart';
import 'package:compound/log_weight/logic/decimal_wheel_value.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:compound/widgets/number_wheel.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:health_repository/health_repository.dart';
import 'package:user_repository/user_repository.dart';

/// Log Weight (Swift `LogWeightView`): the day, the unit, and the weight on
/// a whole-number wheel and a tenths wheel. Opened over the tabs from Scale
/// Weight, Weight Trend and Today.
class LogWeightPage extends StatelessWidget {
  const new({super.key});

  static const path = '/log-weight';
  static const name = 'logWeight';

  @override
  Widget build(BuildContext context) {
    // The router only shows this page while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => LogWeightBloc(
        bodyRepository: context.read<BodyRepository>(),
        healthRepository: context.read<HealthRepository>(),
        userRepository: context.read<UserRepository>(),
        analyticsRepository: context.read<AnalyticsRepository>(),
        uid: state.user.uid,
      )..add(const LogWeightStarted()),
      child: const LogWeightView(),
    );
  }
}

class LogWeightView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<LogWeightBloc>().state;
    return BlocListener<LogWeightBloc, LogWeightState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case LogWeightStatus.saved:
            unawaited(AppHaptics.success());
            _dismiss(context);
          case LogWeightStatus.failure:
            unawaited(AppHaptics.error());
            unawaited(
              showAppDialog<void>(
                context: context,
                title: context.l10n.logWeightSaveFailure,
                actions: [
                  AppDialogAction(
                    label: MaterialLocalizations.of(context).okButtonLabel,
                    role: AppDialogRole.preferred,
                  ),
                ],
              ),
            );
          case LogWeightStatus.loading ||
              LogWeightStatus.ready ||
              LogWeightStatus.saving:
            break;
        }
      },
      child: AppScaffold(
        appBar: AppBar(
          // Always shown, even when opened directly with nothing below.
          leading: AppToolbarButton.close(
            semanticLabel: MaterialLocalizations.of(context).closeButtonLabel,
            onPressed: () => _dismiss(context),
          ),
          title: Text(l10n.logWeightTitle),
          actions: [
            AppToolbarButton.confirm(
              semanticLabel: l10n.logWeightSave,
              isSaving: state.status == LogWeightStatus.saving,
              onPressed: state.isEditable
                  ? () => context.read<LogWeightBloc>().add(
                      const LogWeightSaveRequested(),
                    )
                  : null,
            ),
          ],
        ),
        body: state.status == LogWeightStatus.loading
            ? AppLoadingView(label: l10n.launchLoading)
            : _Form(state: state),
      ),
    );
  }

  /// Back to wherever it was opened from; to Today when opened directly.
  static void _dismiss(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppTab.today.path);
    }
  }
}

class _Form extends StatelessWidget {
  const new({required this.state});

  final LogWeightState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<LogWeightBloc>();
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
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: state.date,
                  firstDate: DateTime(1900),
                  lastDate: now,
                );
                if (picked != null) bloc.add(LogWeightDateChanged(picked));
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        WeightWheels(
          state: state,
          onUnitChanged: (unit) => bloc.add(LogWeightUnitChanged(unit)),
          onWholeChanged: (whole) => bloc.add(LogWeightWholeChanged(whole)),
          onTenthsChanged: (tenths) => bloc.add(LogWeightTenthsChanged(tenths)),
        ),
      ],
    );
  }
}

/// The unit and the weight on a whole-number wheel and a tenths wheel
/// (Swift `WeightPickerInput`), shared by Log Weight and the weekly
/// check-in's weigh-in.
class WeightWheels extends StatelessWidget {
  const new({
    required this.state,
    required this.onUnitChanged,
    required this.onWholeChanged,
    required this.onTenthsChanged,
    super.key,
  });

  /// The unit and both units' wheels.
  final LogWeightState state;
  final ValueChanged<WeightUnitPreference> onUnitChanged;
  final ValueChanged<int> onWholeChanged;
  final ValueChanged<int> onTenthsChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scaler = MediaQuery.textScalerOf(context);
    final kilograms = state.unit == WeightUnitPreference.kilograms;
    final (min, max) = kilograms
        ? (WeightWheelRange.kilograms.min, WeightWheelRange.kilograms.max)
        : (WeightWheelRange.pounds.min, WeightWheelRange.pounds.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: l10n.logWeightUnits,
          container: true,
          child: AppSegmentedControl<WeightUnitPreference>(
            segments: [
              AppSegment(
                value: WeightUnitPreference.kilograms,
                label: l10n.logWeightMetric,
              ),
              AppSegment(
                value: WeightUnitPreference.pounds,
                label: l10n.logWeightImperial,
              ),
            ],
            selected: state.unit,
            onChanged: onUnitChanged,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSection(
          header: l10n.logWeightWeight,
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
                      label: l10n.logWeightWeight,
                      values: [for (var v = min; v <= max; v++) v],
                      selected: kilograms ? state.kilograms : state.pounds,
                      itemLabel: kilograms
                          ? l10n.logWeightWholeKilograms
                          : l10n.logWeightWholePounds,
                      onChanged: onWholeChanged,
                    ),
                  ),
                  Expanded(
                    child: NumberWheel(
                      label: l10n.logWeightTenths,
                      values: DecimalWheelValue.tenths,
                      selected: kilograms
                          ? state.kilogramsTenths
                          : state.poundsTenths,
                      itemLabel: l10n.logWeightTenthsValue,
                      onChanged: onTenthsChanged,
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
