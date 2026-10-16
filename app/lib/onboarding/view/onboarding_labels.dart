import 'package:body_repository/body_repository.dart' show OverarchingObjective;
import 'package:compound/l10n/l10n.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:user_repository/user_repository.dart';

/// The words for each stored answer, from the ARB files.
extension GenderLabel on Gender {
  String label(AppLocalizations l10n) => switch (this) {
    Gender.male => l10n.genderMale,
    Gender.female => l10n.genderFemale,
    Gender.preferNotToSay => l10n.genderPreferNotToSay,
  };
}

extension ExerciseFrequencyLabel on ExerciseFrequency {
  String label(AppLocalizations l10n) => switch (this) {
    ExerciseFrequency.never => l10n.frequencyNever,
    ExerciseFrequency.oneToTwo => l10n.frequencyOneToTwo,
    ExerciseFrequency.threeToFour => l10n.frequencyThreeToFour,
    ExerciseFrequency.fiveToSix => l10n.frequencyFiveToSix,
    ExerciseFrequency.daily => l10n.frequencyDaily,
  };
}

extension ActivityLevelLabel on ActivityLevel {
  String label(AppLocalizations l10n) => switch (this) {
    ActivityLevel.sedentary => l10n.activitySedentary,
    ActivityLevel.light => l10n.activityLight,
    ActivityLevel.moderate => l10n.activityModerate,
    ActivityLevel.active => l10n.activityActive,
    ActivityLevel.veryActive => l10n.activityVeryActive,
  };

  String detail(AppLocalizations l10n) => switch (this) {
    ActivityLevel.sedentary => l10n.activitySedentaryDetail,
    ActivityLevel.light => l10n.activityLightDetail,
    ActivityLevel.moderate => l10n.activityModerateDetail,
    ActivityLevel.active => l10n.activityActiveDetail,
    ActivityLevel.veryActive => l10n.activityVeryActiveDetail,
  };
}

extension ObjectiveLabel on OverarchingObjective {
  String label(AppLocalizations l10n) => switch (this) {
    OverarchingObjective.loseWeight => l10n.objectiveLoseWeight,
    OverarchingObjective.maintain => l10n.objectiveMaintain,
    OverarchingObjective.gainWeight => l10n.objectiveGainWeight,
  };

  String detail(AppLocalizations l10n) => switch (this) {
    OverarchingObjective.loseWeight => l10n.objectiveLoseWeightDetail,
    OverarchingObjective.maintain => l10n.objectiveMaintainDetail,
    OverarchingObjective.gainWeight => l10n.objectiveGainWeightDetail,
  };
}

extension PreferredDietLabel on maths.PreferredDiet {
  String label(AppLocalizations l10n) => switch (this) {
    maths.PreferredDiet.balanced => l10n.dietBalanced,
    maths.PreferredDiet.lowFat => l10n.dietLowFat,
    maths.PreferredDiet.lowCarb => l10n.dietLowCarb,
    maths.PreferredDiet.keto => l10n.dietKeto,
  };

  String detail(AppLocalizations l10n) => switch (this) {
    maths.PreferredDiet.balanced => l10n.dietBalancedDetail,
    maths.PreferredDiet.lowFat => l10n.dietLowFatDetail,
    maths.PreferredDiet.lowCarb => l10n.dietLowCarbDetail,
    maths.PreferredDiet.keto => l10n.dietKetoDetail,
  };
}

extension CalorieDistributionLabel on maths.CalorieDistribution {
  String label(AppLocalizations l10n) => switch (this) {
    maths.CalorieDistribution.even => l10n.distributionEven,
    maths.CalorieDistribution.varied => l10n.distributionVaried,
  };

  String detail(AppLocalizations l10n) => switch (this) {
    maths.CalorieDistribution.even => l10n.distributionEvenDetail,
    maths.CalorieDistribution.varied => l10n.distributionVariedDetail,
  };
}

extension ProteinIntakeLabel on maths.ProteinIntake {
  String label(AppLocalizations l10n) => switch (this) {
    maths.ProteinIntake.low => l10n.proteinLow,
    maths.ProteinIntake.moderate => l10n.proteinModerate,
    maths.ProteinIntake.high => l10n.proteinHigh,
    maths.ProteinIntake.veryHigh => l10n.proteinVeryHigh,
  };

  String detail(AppLocalizations l10n) => switch (this) {
    maths.ProteinIntake.low => l10n.proteinLowDetail,
    maths.ProteinIntake.moderate => l10n.proteinModerateDetail,
    maths.ProteinIntake.high => l10n.proteinHighDetail,
    maths.ProteinIntake.veryHigh => l10n.proteinVeryHighDetail,
  };
}
