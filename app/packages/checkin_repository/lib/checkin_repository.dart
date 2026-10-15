/// The weekly check-in's data for the signed-in user (strategy settings,
/// day annotations, logging break, check-in record) from Firestore, or from
/// memory in the staging flavor; the expenditure engine's inputs assembled
/// from it; and the check-in flow's decisions.
library;

export 'package:compound_maths/compound_maths.dart'
    show CheckInState, ExpenditureEstimate, ExpenditureSource;
export 'package:compound_models/compound_models.dart'
    show
        BmrEquation,
        CheckInRecord,
        ExpenditureAlgorithmVersion,
        ExpenditureCalculationMode,
        ExpenditureEstimationMethod,
        LoggingBreak,
        NutritionDayAnnotation,
        NutritionStrategySettings;

export 'src/check_in_flow.dart';
export 'src/checkin_repository.dart';
export 'src/expenditure_inputs.dart';
export 'src/firestore_checkin_repository.dart';
export 'src/in_memory_checkin_repository.dart';
export 'src/sample_checkin.dart';
