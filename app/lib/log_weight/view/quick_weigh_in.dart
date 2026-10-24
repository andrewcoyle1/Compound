import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_weight/bloc/log_weight_bloc.dart';
import 'package:compound/log_weight/logic/decimal_wheel_value.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_repository/health_repository.dart';
import 'package:user_repository/user_repository.dart';

/// Today's weigh-in logged in place, as rows in an [AppSection]: the weight,
/// opening on the latest weigh-in in the profile's unit, and Save. It is
/// Log Weight without the screen: the same bloc saves it, now, kept to the
/// wheels' span.
class QuickWeighIn extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
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
      child: const QuickWeighInView(),
    );
  }
}

class QuickWeighInView extends StatefulWidget {
  const new({super.key});

  @override
  State<QuickWeighInView> createState() => _QuickWeighInViewState();
}

class _QuickWeighInViewState extends State<QuickWeighInView> {
  /// Whether anything has been typed: until then the field shows the
  /// latest weigh-in.
  var _edited = false;

  /// What was typed; null when it does not read as a number.
  double? _typed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.watch<LogWeightBloc>();
    final state = bloc.state;
    if (state.status == LogWeightStatus.loading) {
      return const AppPlaceholderRow();
    }
    final kilograms = state.unit == WeightUnitPreference.kilograms;
    final range = kilograms
        ? WeightWheelRange.kilograms
        : WeightWheelRange.pounds;
    final weight = !_edited
        ? (kilograms
              ? DecimalWheelValue.combine(
                  whole: state.kilograms,
                  tenths: state.kilogramsTenths,
                )
              : DecimalWheelValue.combine(
                  whole: state.pounds,
                  tenths: state.poundsTenths,
                ))
        : _typed;
    final valid =
        weight != null && weight >= range.min && weight < range.max + 1;
    final saving = state.status == LogWeightStatus.saving;
    return BlocListener<LogWeightBloc, LogWeightState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case LogWeightStatus.saved:
            unawaited(AppHaptics.success());
          case LogWeightStatus.failure:
            unawaited(AppHaptics.error());
            showAppSnackBar(
              context,
              l10n.logWeightSaveFailure,
              style: AppSnackBarStyle.error,
            );
          case LogWeightStatus.loading ||
              LogWeightStatus.ready ||
              LogWeightStatus.saving:
            break;
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNumberField(
            key: const Key('QuickWeighIn.weight'),
            label: l10n.quickWeighInWeight,
            value: weight,
            prompt: '0',
            // Unit symbols read the same in every language.
            unit: kilograms ? 'kg' : 'lb',
            onChanged: (value) => setState(() {
              _edited = true;
              _typed = value;
            }),
          ),
          AppListRowButton(
            title: l10n.quickWeighInSave,
            icon: AppSymbols.scaleWeight,
            accessory: saving
                ? const AppListRowCustom(AppSpinner(size: AppSpinnerSize.small))
                : null,
            onPressed: valid && state.isEditable
                ? () => bloc.add(LogWeightSaveRequested(weight))
                : null,
          ),
        ],
      ),
    );
  }
}
