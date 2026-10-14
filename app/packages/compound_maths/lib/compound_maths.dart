/// A pure Dart port of the figures the Compound app computes for the user:
/// expenditure, the weight trend, formula expenditure, estimated one-rep maxes
/// and weekly sets per muscle.
///
/// The Swift app is the source of truth. `functions/coach-maths.js` is the
/// server's copy, and `CompoundUnitTests/Fixtures/coach-parity.json` holds
/// cases all three are checked against.
library;

export 'src/day_key.dart';
export 'src/energy_density.dart';
export 'src/expenditure_engine.dart';
export 'src/expenditure_filter.dart';
export 'src/expenditure_samples.dart';
export 'src/formula_expenditure.dart';
export 'src/muscle_volume.dart';
export 'src/one_rep_max.dart';
export 'src/weight_trend.dart';
export 'src/workout.dart';
