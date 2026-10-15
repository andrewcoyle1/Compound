/// A pure Dart port of the figures the Compound app computes for the user:
/// expenditure, the weight trend, formula expenditure, estimated one-rep maxes,
/// weekly sets per muscle with their tiers and the volume suggestion, the
/// weekly training streak, and the nutrition targets, target proposals and
/// check-in schedule built on them.
///
/// The Swift app is the source of truth. `functions/coach-maths.js` is the
/// server's copy, and `CompoundUnitTests/Fixtures/coach-parity.json` holds
/// cases all three are checked against; `nutrition-parity.json` beside it holds
/// the nutrition cases the Swift and this port are checked against.
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
