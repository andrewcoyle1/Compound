import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/settings/nutrition/cubit/settings_document_cubit.dart';

/// The nutrition strategy settings, which the Strategy and Expenditure
/// screens both edit (Swift `StrategySettingsPresenter`,
/// `ExpenditureSettingsPresenter`). Clearing the calculation start date
/// deletes it in Firestore, which Swift's merge never does.
class StrategySettingsCubit
    extends SettingsDocumentCubit<NutritionStrategySettings> {
  new({
    required CheckInRepository checkInRepository,
    required super.analytics,
    required String uid,
    required super.screen,
  }) : super(
         document: checkInRepository.watchStrategySettings(uid),
         save: checkInRepository.saveStrategySettings,
         decode: NutritionStrategySettings.fromFirestore,
         encode: (settings) => settings.toFirestore(),
       );
}
