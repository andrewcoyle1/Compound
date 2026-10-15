// The Dart half of the Firestore contract
// (docs/specs/flutter/firestore-contract.md). The fixtures in
// contracts/firestore/ are recorded from the Swift models; every one must
// decode here, and the canonical ones must come back from
// fromFirestore -> toFirestore exactly, keys and number types included.
import 'dart:convert';
import 'dart:io';

import 'package:compound_models/compound_models.dart';
import 'package:test/test.dart';

/// Each model folder in contracts/firestore/, with its Dart round trip and
/// field-name constants. A folder Swift adds fails until it is listed here.
final _models =
    <
      String,
      ({
        Map<String, Object?> Function(Map<String, Object?>) roundTrip,
        List<String> keys,
      })
    >{
      'user_model': (
        roundTrip: (data) => UserModel.fromFirestore(data).toFirestore(),
        keys: UserModelKeys.all,
      ),
      'private_user_settings': (
        roundTrip: (data) =>
            PrivateUserSettings.fromFirestore(data).toFirestore(),
        keys: PrivateUserSettingsKeys.all,
      ),
      'workout_session': (
        roundTrip: (data) =>
            WorkoutSessionModel.fromFirestore(data).toFirestore(),
        keys: WorkoutSessionModelKeys.all,
      ),
      'workout_exercise': (
        roundTrip: (data) =>
            WorkoutExerciseModel.fromFirestore(data).toFirestore(),
        keys: WorkoutExerciseModelKeys.all,
      ),
      'workout_set': (
        roundTrip: (data) => WorkoutSetModel.fromFirestore(data).toFirestore(),
        keys: WorkoutSetModelKeys.all,
      ),
      'set_target': (
        roundTrip: (data) => SetTarget.fromFirestore(data).toFirestore(),
        keys: SetTargetKeys.all,
      ),
      'equipment_variation': (
        roundTrip: (data) =>
            EquipmentVariation.fromFirestore(data).toFirestore(),
        keys: EquipmentVariationKeys.all,
      ),
      'meal_log': (
        roundTrip: (data) => MealLogModel.fromFirestore(data).toFirestore(),
        keys: MealLogModelKeys.all,
      ),
      'meal_item': (
        roundTrip: (data) => MealItemModel.fromFirestore(data).toFirestore(),
        keys: MealItemModelKeys.all,
      ),
      'nutrient_map': (
        roundTrip: (data) => NutrientMap.fromFirestore(data).toFirestore(),
        keys: NutrientMapKeys.all,
      ),
      'diet_plan': (
        roundTrip: (data) => DietPlan.fromFirestore(data).toFirestore(),
        keys: DietPlanKeys.all,
      ),
      'daily_macro_target': (
        roundTrip: (data) => DailyMacroTarget.fromFirestore(data).toFirestore(),
        keys: DailyMacroTargetKeys.all,
      ),
      'food_log_settings': (
        roundTrip: (data) => FoodLogSettings.fromFirestore(data).toFirestore(),
        keys: FoodLogSettingsKeys.all,
      ),
      'body_measurement': (
        roundTrip: (data) =>
            BodyMeasurementEntry.fromFirestore(data).toFirestore(),
        keys: BodyMeasurementEntryKeys.all,
      ),
      'steps': (
        roundTrip: (data) => StepsModel.fromFirestore(data).toFirestore(),
        keys: StepsModelKeys.all,
      ),
      'analytics_settings': (
        roundTrip: (data) =>
            AnalyticsSettings.fromFirestore(data).toFirestore(),
        keys: AnalyticsSettingsKeys.all,
      ),
      'weight_goal': (
        roundTrip: (data) => WeightGoal.fromFirestore(data).toFirestore(),
        keys: WeightGoalKeys.all,
      ),
      'exercise_model': (
        roundTrip: (data) => ExerciseModel.fromFirestore(data).toFirestore(),
        keys: ExerciseModelKeys.all,
      ),
      'exercise_settings': (
        roundTrip: (data) =>
            ExerciseSettingsModel.fromFirestore(data).toFirestore(),
        keys: ExerciseSettingsModelKeys.all,
      ),
      'workout_template': (
        roundTrip: (data) =>
            WorkoutTemplateModel.fromFirestore(data).toFirestore(),
        keys: WorkoutTemplateModelKeys.all,
      ),
      'workout_template_exercise': (
        roundTrip: (data) =>
            WorkoutTemplateExercise.fromFirestore(data).toFirestore(),
        keys: WorkoutTemplateExerciseKeys.all,
      ),
      'workout_settings': (
        roundTrip: (data) => WorkoutSettings.fromFirestore(data).toFirestore(),
        keys: WorkoutSettingsKeys.all,
      ),
      'gym_profile': (
        roundTrip: (data) => GymProfileModel.fromFirestore(data).toFirestore(),
        keys: GymProfileModelKeys.all,
      ),
      'gym_free_weights': (
        roundTrip: (data) => FreeWeights.fromFirestore(data).toFirestore(),
        keys: GymEquipmentKeys.freeWeightsFields,
      ),
      'gym_body_weights': (
        roundTrip: (data) => BodyWeights.fromFirestore(data).toFirestore(),
        keys: GymEquipmentKeys.rangedFields,
      ),
      'gym_bands': (
        roundTrip: (data) => Bands.fromFirestore(data).toFirestore(),
        keys: GymEquipmentKeys.rangedFields,
      ),
      'gym_loadable_bars': (
        roundTrip: (data) => LoadableBars.fromFirestore(data).toFirestore(),
        keys: GymEquipmentKeys.loadableBarsFields,
      ),
      'gym_fixed_weight_bars': (
        roundTrip: (data) => FixedWeightBars.fromFirestore(data).toFirestore(),
        keys: GymEquipmentKeys.fixedWeightBarsFields,
      ),
      'gym_support_equipment': (
        roundTrip: (data) => PlainEquipment.fromFirestore(data).toFirestore(),
        keys: GymEquipmentKeys.plainFields,
      ),
      'gym_accessory_equipment': (
        roundTrip: (data) => PlainEquipment.fromFirestore(data).toFirestore(),
        keys: GymEquipmentKeys.plainFields,
      ),
      'gym_loadable_accessory_equipment': (
        roundTrip: (data) =>
            LoadableAccessoryEquipment.fromFirestore(data).toFirestore(),
        keys: GymEquipmentKeys.loadableAccessoryFields,
      ),
      'gym_cable_machine': (
        roundTrip: (data) => StackMachine.fromFirestore(data).toFirestore(),
        keys: GymEquipmentKeys.stackMachineFields,
      ),
      'gym_pin_loaded_machine': (
        roundTrip: (data) => StackMachine.fromFirestore(data).toFirestore(),
        keys: GymEquipmentKeys.stackMachineFields,
      ),
      'gym_plate_loaded_machine': (
        roundTrip: (data) =>
            PlateLoadedMachine.fromFirestore(data).toFirestore(),
        keys: GymEquipmentKeys.plateLoadedMachineFields,
      ),
      'mesocycle': (
        roundTrip: (data) => Mesocycle.fromFirestore(data).toFirestore(),
        keys: MesocycleKeys.all,
      ),
      'macrocycle': (
        roundTrip: (data) => Macrocycle.fromFirestore(data).toFirestore(),
        keys: MacrocycleKeys.all,
      ),
      'food_model': (
        roundTrip: (data) => FoodModel.fromFirestore(data).toFirestore(),
        keys: FoodModelKeys.all,
      ),
      'nutrition_strategy_settings': (
        roundTrip: (data) =>
            NutritionStrategySettings.fromFirestore(data).toFirestore(),
        keys: NutritionStrategySettingsKeys.all,
      ),
      'check_in_record': (
        roundTrip: (data) => CheckInRecord.fromFirestore(data).toFirestore(),
        keys: CheckInRecordKeys.all,
      ),
      'logging_break': (
        roundTrip: (data) => LoggingBreak.fromFirestore(data).toFirestore(),
        keys: LoggingBreakKeys.all,
      ),
      'nutrition_day_annotation': (
        roundTrip: (data) =>
            NutritionDayAnnotation.fromFirestore(data).toFirestore(),
        keys: NutritionDayAnnotationKeys.all,
      ),
      'shortcut_settings': (
        roundTrip: (data) => ShortcutSettings.fromFirestore(data).toFirestore(),
        keys: ShortcutSettingsKeys.all,
      ),
      'follow_request': (
        roundTrip: (data) =>
            FollowRequestModel.fromFirestore(data).toFirestore(),
        keys: FollowRequestModelKeys.all,
      ),
      'activity_notification': (
        roundTrip: (data) =>
            ActivityNotificationModel.fromFirestore('n', data).toFirestore(),
        keys: ActivityNotificationModelKeys.all,
      ),
      'session_comment': (
        roundTrip: (data) =>
            WorkoutSessionComment.fromFirestore(data).toFirestore(),
        keys: WorkoutSessionCommentKeys.all,
      ),
      'report': (
        roundTrip: (data) => ReportModel.fromFirestore(data).toFirestore(),
        keys: ReportModelKeys.all,
      ),
      'username_reservation': (
        roundTrip: (data) =>
            UsernameReservation.fromFirestore(data).toFirestore(),
        keys: UsernameReservationKeys.all,
      ),
      'challenge': (
        roundTrip: (data) => ChallengeModel.fromFirestore(data).toFirestore(),
        keys: ChallengeModelKeys.all,
      ),
      'challenge_progress': (
        roundTrip: (data) =>
            ChallengeProgressModel.fromFirestore(data).toFirestore(),
        keys: ChallengeProgressModelKeys.all,
      ),
      'invite': (
        roundTrip: (data) => InviteModel.fromFirestore(data).toFirestore(),
        keys: InviteModelKeys.all,
      ),
      'share': (
        roundTrip: (data) => ShareModel.fromFirestore(data).toFirestore(),
        keys: ShareModelKeys.all,
      ),
    };

final _root = Directory('../../../contracts/firestore');

Map<String, Object?> _read(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

File _fixture(String model, String name) =>
    File('${_root.path}/$model/$name.json');

List<String> _caseNames(String model) =>
    Directory('${_root.path}/$model')
        .listSync()
        .map((entry) => entry.uri.pathSegments.last)
        .where((n) => n.endsWith('.json') && !n.endsWith('.expected.json'))
        .map((n) => n.substring(0, n.length - '.json'.length))
        .toList()
      ..sort();

Map<String, Object?> _roundTrip(String model, Map<String, Object?> tagged) =>
    firestoreToTaggedJson(
      _models[model]!.roundTrip(taggedJsonToFirestore(tagged)),
    );

/// Equal values of the same JSON type: an int never matches a double, so a
/// Dart write cannot change a field's Firestore type unnoticed.
Matcher _strictlyEquals(Object? expected) => predicate<Object?>(
  (actual) => _strictEqual(actual, expected),
  'strictly equals ${jsonEncode(expected)}',
);

bool _strictEqual(Object? a, Object? b) => switch ((a, b)) {
  (final Map<String, Object?> x, final Map<String, Object?> y) =>
    x.length == y.length &&
        x.keys.every((k) => y.containsKey(k) && _strictEqual(x[k], y[k])),
  (final List<Object?> x, final List<Object?> y) =>
    x.length == y.length &&
        [for (var i = 0; i < x.length; i++) i]
            .every((i) => _strictEqual(x[i], y[i])),
  _ => a.runtimeType == b.runtimeType && a == b,
};

void main() {
  test('every contract folder has a Dart model', () {
    final folders = _root
        .listSync()
        .whereType<Directory>()
        .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
        .toSet();
    expect(folders, equals(_models.keys.toSet()));
  });

  for (final model in _models.keys) {
    group(model, () {
      test('has full and minimal fixtures', () {
        expect(_caseNames(model), containsAll(['full', 'minimal']));
      });

      for (final name in _caseNames(model)) {
        if (name.startsWith('legacy-')) {
          test('$name decodes to $name.expected.json', () {
            expect(
              _roundTrip(model, _read(_fixture(model, name))),
              _strictlyEquals(_read(_fixture(model, '$name.expected'))),
            );
          });
        } else {
          test('$name re-encodes to exactly itself', () {
            final fixture = _read(_fixture(model, name));
            expect(_roundTrip(model, fixture), _strictlyEquals(fixture));
          });
        }
      }

      test('field-name constants are exactly the full fixture keys', () {
        expect(
          _models[model]!.keys.toSet(),
          equals(_read(_fixture(model, 'full')).keys.toSet()),
        );
      });
    });
  }

  test('enum raw values match contracts/firestore/enums.json', () {
    final enums = _read(File('${_root.path}/enums.json'));
    List<String> raw(List<FirestoreEnum> values) => [
      for (final v in values) v.value,
    ];
    expect(
      enums,
      equals({
        'ActivityLevel': raw(ActivityLevel.values),
        'EquipmentKind': raw(EquipmentKind.values),
        'ExerciseWeightUnit': raw(ExerciseWeightUnit.values),
        'SetKind': raw(SetKind.values),
        'SetSide': raw(SetSide.values),
        'SetTargetSetType': raw(SetTargetSetType.values),
        'TrackingMode': raw(TrackingMode.values),
        'CardioFitnessLevel': raw(CardioFitnessLevel.values),
        'DistanceUnitPreference': raw(DistanceUnitPreference.values),
        'ExerciseFrequency': raw(ExerciseFrequency.values),
        'Gender': raw(Gender.values),
        'LengthUnitPreference': raw(LengthUnitPreference.values),
        'WeightUnitPreference': raw(WeightUnitPreference.values),
        'MealItemSourceType': raw(MealItemSourceType.values),
        'NutrientKey': raw(NutrientKey.values),
        'TimestampSide': raw(TimestampSide.values),
        'WeightSource': raw(WeightSource.values),
        'StepsSource': raw(StepsSource.values),
        'GoalStatus': raw(GoalStatus.values),
        'OverarchingObjective': raw(OverarchingObjective.values),
        'Muscles': raw(Muscles.values),
        'MuscleTargetType': raw(MuscleTargetType.values),
        'TrackableExerciseMetric': raw(TrackableExerciseMetric.values),
        'ExerciseType': raw(ExerciseType.values),
        'Laterality': raw(Laterality.values),
        'PreviousWorkoutReferenceOption': raw(
          PreviousWorkoutReferenceOption.values,
        ),
        'InitialLogFillOption': raw(InitialLogFillOption.values),
        'ProgressionAdjustmentMode': raw(ProgressionAdjustmentMode.values),
        'DeloadType': raw(DeloadType.values),
        'MacrocycleStatus': raw(MacrocycleStatus.values),
        'MeasurementMethod': raw(MeasurementMethod.values),
        'ExpenditureEstimationMethod': raw(ExpenditureEstimationMethod.values),
        'BMREquation': raw(BmrEquation.values),
        'ExpenditureCalculationMode': raw(ExpenditureCalculationMode.values),
        'ExpenditureAlgorithmVersion': raw(ExpenditureAlgorithmVersion.values),
        'FollowRequestStatus': raw(FollowRequestStatus.values),
        'ShareStatus': raw(ShareStatus.values),
        'ActivityType': raw(ActivityType.values),
        'ReportContentType': raw(ReportContentType.values),
        'ReportReason': raw(ReportReason.values),
      }),
    );
  });
}
