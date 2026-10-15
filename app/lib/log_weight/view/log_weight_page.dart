import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_weight/bloc/log_weight_bloc.dart';
import 'package:compound/log_weight/logic/decimal_wheel_value.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPicker;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
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
            unawaited(HapticFeedback.successNotification());
            _dismiss(context);
          case LogWeightStatus.failure:
            unawaited(HapticFeedback.errorNotification());
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(context.l10n.logWeightSaveFailure),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      MaterialLocalizations.of(context).okButtonLabel,
                    ),
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
      child: Scaffold(
        appBar: AppBar(
          // Always shown, even when opened directly with nothing below.
          leading: CloseButton(onPressed: () => _dismiss(context)),
          title: Text(l10n.logWeightTitle),
          actions: [
            if (state.status == LogWeightStatus.saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            else
              IconButton(
                icon: const Icon(AppSymbols.selected),
                tooltip: l10n.logWeightSave,
                onPressed: state.isEditable
                    ? () => context.read<LogWeightBloc>().add(
                        const LogWeightSaveRequested(),
                      )
                    : null,
              ),
          ],
        ),
        body: state.status == LogWeightStatus.loading
            ? const Center(child: CircularProgressIndicator.adaptive())
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
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scaler = MediaQuery.textScalerOf(context);
    final kilograms = state.unit == WeightUnitPreference.kilograms;
    final (min, max) = kilograms
        ? (WeightWheelRange.kilograms.min, WeightWheelRange.kilograms.max)
        : (WeightWheelRange.pounds.min, WeightWheelRange.pounds.max);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        AppSection(
          children: [
            AppListRowButton(
              title: l10n.logWeightDate,
              accessory: AppListRowValue(
                DateFormat.yMMMd(locale).format(state.date),
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
        Semantics(
          label: l10n.logWeightUnits,
          container: true,
          child: SegmentedButton<WeightUnitPreference>(
            segments: [
              ButtonSegment(
                value: WeightUnitPreference.kilograms,
                label: Text(l10n.logWeightMetric),
              ),
              ButtonSegment(
                value: WeightUnitPreference.pounds,
                label: Text(l10n.logWeightImperial),
              ),
            ],
            selected: {state.unit},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                bloc.add(LogWeightUnitChanged(selection.single)),
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
                    child: _Wheel(
                      label: l10n.logWeightWeight,
                      values: [for (var v = min; v <= max; v++) v],
                      selected: kilograms ? state.kilograms : state.pounds,
                      itemLabel: kilograms
                          ? l10n.logWeightWholeKilograms
                          : l10n.logWeightWholePounds,
                      onChanged: (whole) =>
                          bloc.add(LogWeightWholeChanged(whole)),
                    ),
                  ),
                  Expanded(
                    child: _Wheel(
                      label: l10n.logWeightTenths,
                      values: DecimalWheelValue.tenths,
                      selected: kilograms
                          ? state.kilogramsTenths
                          : state.poundsTenths,
                      itemLabel: l10n.logWeightTenthsValue,
                      onChanged: (tenths) =>
                          bloc.add(LogWeightTenthsChanged(tenths)),
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

/// One wheel. Screen readers hear its [label] and the row shown, and swipe
/// up or down to adjust it.
class _Wheel extends StatefulWidget {
  const new({
    required this.label,
    required this.values,
    required this.selected,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final List<int> values;
  final int selected;
  final String Function(int value) itemLabel;
  final ValueChanged<int> onChanged;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final _controller = FixedExtentScrollController(
    initialItem: widget.values.indexOf(widget.selected),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        label: widget.label,
        child: CupertinoPicker(
          scrollController: _controller,
          itemExtent: MediaQuery.textScalerOf(context).scale(32),
          onSelectedItemChanged: (index) =>
              widget.onChanged(widget.values[index]),
          children: [
            for (final value in widget.values)
              Center(child: Text(widget.itemLabel(value))),
          ],
        ),
      ),
    );
  }
}
