import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_measurement/log_measurement.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/progress/bloc/progress_bloc.dart';
import 'package:compound/progress/bloc/progress_figures.dart';
import 'package:compound/progress/logic/body_metrics.dart';
import 'package:compound/progress/view/progress_cards.dart';
import 'package:compound/progress/view/progress_metric_view.dart';
import 'package:compound/progress/view/progress_names.dart';
import 'package:compound/progress/view/progress_provider.dart';
import 'package:compound/progress_photos/progress_photos.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound_maths/compound_maths.dart'
    show BodyRatioBand, BodyRatioKind, Gender, bodyRatioBand;
import 'package:compound_models/compound_models.dart'
    show BodyMeasurementEntryKeys;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Body Metrics (Swift `BodyMetricsView`): scale weight and visual body
/// fat, the eighteen circumferences in three groups, and the two ratios,
/// each card opening its history, and the row to Progress Photos.
class BodyMetricsPage extends StatelessWidget {
  const new({super.key});

  /// The path under the Progress tab, and the route name.
  static const path = 'body-metrics';
  static const name = 'bodyMetrics';

  @override
  Widget build(BuildContext context) => ProgressProvider(
    screen: 'BodyMetricsView',
    child: ProgressSectionsView(
      title: context.l10n.progressBodyMetricsHeader,
      sections: (context, state) {
        final l10n = context.l10n;
        final cards = ProgressCards(context, state);
        return [
          for (final group in BodyMetricsGroup.values)
            ProgressCardSection(
              header: bodyMetricsGroupName(l10n, group),
              cards: group == BodyMetricsGroup.weightAndBodyFat
                  ? [cards.scaleWeight(), cards.bodyFat()]
                  : [for (final kind in group.kinds) cards.measurement(kind)],
            ),
          ProgressCardSection(
            header: l10n.bodyMetricsRatios,
            cards: [
              // No waist, no ratio: one card saying so, not two blanks.
              if (state.ratioReadings(BodyRatioKind.waistToHip).isEmpty &&
                  state.ratioReadings(BodyRatioKind.waistToHeight).isEmpty)
                ProgressMessage(
                  title: l10n.bodyMetricsRatios,
                  message: l10n.bodyMetricsRatiosEmpty,
                  icon: AppSymbols.measurement,
                )
              else
                for (final kind in BodyRatioKind.values) cards.ratio(kind),
            ],
          ),
          AppSection(
            header: l10n.progressPhotosHeader,
            children: [
              AppListRowButton(
                title: l10n.progressPhotosTitle,
                icon: AppSymbols.progressPhotos,
                onPressed: () =>
                    unawaited(context.pushNamed(ProgressPhotosPage.name)),
              ),
            ],
          ),
        ];
      },
    ),
  );
}

/// One body metric's history (Swift `BodyMeasurementDetail`,
/// `VisualBodyFatMetric` and `BodyRatioMetric`): a circumference when
/// [kind] is given, a ratio when [ratio] is, visual body fat otherwise.
/// Logged readings can be deleted from All Recorded Data; a ratio is
/// derived, so it cannot.
class BodyMetricDetailPage extends StatelessWidget {
  const new({this.kind, this.ratio, this.allData = false, super.key});

  /// The page for the metric [id] names: a circumference's or ratio's
  /// raw value, or [bodyFatId].
  factory forId(String? id, {bool allData = false}) => BodyMetricDetailPage(
    kind: BodyMeasurementKind.tryParse(id),
    ratio: BodyRatioKind.values.where((r) => r.name == id).firstOrNull,
    allData: allData,
  );

  /// The path under Body Metrics, and the route names.
  static const path = ':$metricParameter';
  static const name = 'bodyMetricDetail';
  static const dataName = 'bodyMetricDetailData';

  /// The metric's path parameter.
  static const metricParameter = 'metric';

  /// Visual body fat's id in the path.
  static const bodyFatId = 'visualBodyFat';

  /// The circumference, if this is one.
  final BodyMeasurementKind? kind;

  /// The ratio, if this is one.
  final BodyRatioKind? ratio;

  /// Whether to show every entry instead of the chart.
  final bool allData;

  @override
  Widget build(BuildContext context) {
    final kind = this.kind;
    final ratio = this.ratio;
    final (screen, parameters, id) = kind != null
        ? ('BodyMeasurementDetailView', {'measurement': kind.name}, kind.name)
        : ratio != null
        ? ('BodyRatioView', {'ratio': ratio.name}, ratio.name)
        : ('VisualBodyFatView', null, bodyFatId);
    return ProgressProvider(
      screen: screen,
      parameters: parameters,
      child: OnAppear(
        // Visual body fat comes from Apple Health or Health Connect.
        onAppear: () {
          if (kind == null && ratio == null) {
            unawaited(context.read<HealthCubit>().syncBody());
          }
        },
        child: ProgressMetricView(
          allData: allData,
          allDataRoute: dataName,
          pathParameters: {metricParameter: id},
          metric: (context, state) => kind != null
              ? _measurement(context, state, kind)
              : ratio != null
              ? _ratio(context, state, ratio)
              : _bodyFat(context, state),
        ),
      ),
    );
  }

  static ProgressMetric _measurement(
    BuildContext context,
    ProgressState state,
    BodyMeasurementKind kind,
  ) {
    final l10n = context.l10n;
    final name = bodyMeasurementName(l10n, kind);
    final readings = state.measurementReadings(kind);
    final title = l10n.measurementCircumference(name);
    return ProgressMetric(
      title: title,
      unit: state.lengthSymbol,
      series: [
        MetricChartSeries(
          label: title,
          points: _points(readings),
          color: context.appColors.measurements,
          isLine: true,
        ),
      ],
      entries: _points(readings),
      entryIds: [for (final r in readings) r.id],
      deleteFields: {kind.key},
      emptyMessage: l10n.measurementEmpty(name.toLowerCase()),
      add: _logMeasurement(context, kind, l10n.metricAdd, AppSymbols.add),
    );
  }

  static ProgressMetric _bodyFat(BuildContext context, ProgressState state) {
    final l10n = context.l10n;
    final readings = state.bodyFatReadings;
    return ProgressMetric(
      title: l10n.progressVisualBodyFat,
      unit: '%',
      series: [
        MetricChartSeries(
          label: l10n.bodyFatSeries,
          points: _points(readings),
          color: context.appColors.bodyFat,
          isLine: true,
        ),
      ],
      entries: _points(readings),
      entryIds: [for (final r in readings) r.id],
      deleteFields: const {BodyMeasurementEntryKeys.bodyFatPercentage},
      emptyMessage: l10n.bodyFatEmpty,
      // No manual entry: re-reading all of Health also picks up history
      // from before body fat access was granted.
      add: ProgressMetricAction(
        label: l10n.healthSync(context),
        icon: AppSymbols.sync,
        onPressed: () => unawaited(context.read<HealthCubit>().syncBody()),
      ),
    );
  }

  static ProgressMetric _ratio(
    BuildContext context,
    ProgressState state,
    BodyRatioKind kind,
  ) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final readings = state.ratioReadings(kind);
    final points = _points(readings);
    return ProgressMetric(
      title: bodyRatioName(l10n, kind),
      unit: '',
      decimals: 2,
      series: [
        MetricChartSeries(
          label: l10n.bodyRatioSeries,
          points: points,
          color: context.appColors.measurements,
          isLine: true,
        ),
      ],
      entries: points,
      entryText: (index) =>
          ratioText(points[points.length - 1 - index].value, locale),
      emptyMessage: switch (kind) {
        BodyRatioKind.waistToHeight => l10n.bodyRatioWaistToHeightRequirement,
        BodyRatioKind.waistToHip => l10n.bodyRatioWaistToHipRequirement,
      },
      info: switch (kind) {
        BodyRatioKind.waistToHeight => MethodInfo.waistToHeightRatio(l10n),
        BodyRatioKind.waistToHip => MethodInfo.waistToHipRatio(l10n),
      },
      summary: points.isEmpty
          ? null
          : RatioScreening(
              kind: kind,
              latest: points.last.value,
              sex: state.sex,
            ),
      // A ratio is worked out, but the waist is what both need.
      add: _logMeasurement(
        context,
        BodyMeasurementKind.waist,
        l10n.bodyRatioLogWaist,
        AppSymbols.add,
      ),
    );
  }

  static List<MetricPoint> _points(List<BodyReading> readings) => [
    for (final r in readings) (date: r.date, value: r.value),
  ];

  static ProgressMetricAction _logMeasurement(
    BuildContext context,
    BodyMeasurementKind kind,
    String label,
    IconData icon,
  ) => ProgressMetricAction(
    label: label,
    icon: icon,
    onPressed: () => LogMeasurementPage.show(context, kind),
  );
}

/// The latest ratio and its screening band, with the bands it was judged
/// against (Swift `BodyRatioPresenter.summarySection`).
class RatioScreening extends StatelessWidget {
  const new({
    required this.kind,
    required this.latest,
    required this.sex,
    super.key,
  });

  /// Which ratio.
  final BodyRatioKind kind;

  /// Its latest value.
  final double latest;

  /// The profile's sex, which picks the waist-to-hip cut-off.
  final Gender? sex;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final band = bodyRatioBand(kind, latest, sex);
    return AppSection(
      header: l10n.bodyRatioScreening,
      footer: switch (kind) {
        BodyRatioKind.waistToHeight => l10n.bodyRatioWaistToHeightBands,
        BodyRatioKind.waistToHip => switch (sex) {
          Gender.male => l10n.bodyRatioWaistToHipBandsMen,
          Gender.female => l10n.bodyRatioWaistToHipBandsWomen,
          Gender.preferNotToSay || null => l10n.bodyRatioWaistToHipBands,
        },
      },
      children: [
        AppListRow(
          title: l10n.bodyRatioLatest,
          accessory: AppListRowValue(ratioText(latest, locale)),
        ),
        // The band as the row's title, so a long one wraps rather than
        // squeezing the label; a glyph as well as a colour.
        if (band != null)
          AppListRow(
            title: switch (band) {
              BodyRatioBand.underHalfHeight => l10n.bodyRatioUnderHalfHeight,
              BodyRatioBand.increasedRisk => l10n.bodyRatioIncreasedRisk,
              BodyRatioBand.highRisk => l10n.bodyRatioHighRisk,
              BodyRatioBand.belowCutOff => l10n.bodyRatioBelowCutOff,
              BodyRatioBand.substantiallyIncreasedRisk =>
                l10n.bodyRatioSubstantiallyIncreased,
            },
            subtitle: l10n.bodyRatioBand,
            icon: band.isConcern ? AppSymbols.warning : AppSymbols.success,
            tint: band.isConcern ? colors.warning : colors.success,
          ),
      ],
    );
  }
}
