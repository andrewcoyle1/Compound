/// A pure Dart port of the figures the Compound app computes for the user:
/// expenditure, the weight trend, formula expenditure, estimated one-rep maxes,
/// weekly sets per muscle with their tiers and the volume suggestion, the
/// weekly training streak, and the nutrition targets, target proposals and
/// check-in schedule built on them.
///
/// Ported from the Swift app, now archived. `functions/coach-maths.js` is the
/// server's copy, and `contracts/fixtures/coach-parity.json` holds cases both
/// are checked against; `nutrition-parity.json` beside it holds the nutrition
/// cases the Swift app recorded for this port.
library;

export 'src/body_ratio.dart';
export 'src/check_in_schedule.dart';
export 'src/daily_macros.dart';
export 'src/day_key.dart';
export 'src/energy_balance.dart';
export 'src/energy_density.dart';
export 'src/expenditure_engine.dart';
export 'src/expenditure_filter.dart';
export 'src/expenditure_samples.dart';
export 'src/formula_expenditure.dart';
export 'src/muscle_volume.dart';
export 'src/nutrition_targets.dart';
export 'src/one_rep_max.dart';
export 'src/target_proposal.dart';
export 'src/volume_recommendation.dart';
export 'src/weekly_streak.dart';
export 'src/weight_trend.dart';
export 'src/workout.dart';
