import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:training_rules/training_rules.dart' as r;

/// How a weight goes on the bar (`PlateLoadingView`): one sleeve drawn with
/// its plates, the plates counted, and the sum that makes the total. Over
/// the weight keypad and at the top of the plate calculator.
class PlateLoadingView extends StatelessWidget {
  const new({
    required this.loading,
    required this.plates,
    required this.unit,
    this.showsEquation = true,
    super.key,
  });

  final r.PlateLoading loading;

  /// The gym's plates, for their colours.
  final List<r.Plate> plates;
  final ExerciseWeightUnit unit;

  /// Off where the sum has a line of its own, as over the keypad.
  final bool showsEquation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context);
    const figures = [FontFeature.tabularFigures()];
    return MergeSemantics(
      child: Row(
        spacing: AppSpacing.m,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              width: scale.scale(88),
              height: scale.scale(40),
              child: CustomPaint(
                painter: _SleevePainter(
                  perSide: loading.perSide,
                  colours: [
                    for (final weight in loading.perSide)
                      _colour(weight) ?? scheme.onSurface,
                  ],
                  bar: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: [
                if (loading.perSide.isNotEmpty)
                  Text(
                    TrackerText.plateCounts(loading, locale: locale),
                    style: AppTextStyles.rowTitle.copyWith(
                      fontFeatures: figures,
                    ),
                  ),
                if (showsEquation)
                  Text(
                    TrackerText.plateEquation(
                      l10n,
                      loading,
                      unit,
                      locale: locale,
                    ),
                    style: AppTextStyles.rowDetail.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: figures,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color? _colour(double weight) => AppColors.fromHex(
    plates
        .where((plate) => (plate.weight - weight).abs() < 0.001)
        .firstOrNull
        ?.colour,
  );
}

/// One sleeve, collar on the left and plates outward from it: taller for
/// heavier, in the gym's colour for that plate.
class _SleevePainter extends CustomPainter {
  const new({required this.perSide, required this.colours, required this.bar});

  final List<double> perSide;
  final List<Color> colours;
  final Color bar;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final paint = Paint()..color = bar;
    canvas
      ..drawRect(Rect.fromLTWH(0, mid - 2, size.width, 4), paint)
      ..drawRect(
        Rect.fromLTWH(
          size.width * 0.12,
          mid - size.height * 0.18,
          4,
          size.height * 0.36,
        ),
        paint,
      );
    final heaviest = perSide.fold<double>(1, math.max);
    final width = math
        .max(3, math.min(8, size.width * 0.8 / math.max(perSide.length, 1) - 1))
        .toDouble();
    var left = size.width * 0.12 + 5;
    for (final (index, weight) in perSide.indexed) {
      final height = size.height * (0.4 + 0.6 * weight / heaviest);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, mid - height / 2, width, height),
          // A plate's edge, rounded in proportion to its drawn width.
          Radius.circular(width / 8),
        ),
        Paint()..color = colours[index],
      );
      left += width + 1;
    }
  }

  @override
  bool shouldRepaint(_SleevePainter oldDelegate) =>
      oldDelegate.perSide != perSide ||
      oldDelegate.colours != colours ||
      oldDelegate.bar != bar;
}
