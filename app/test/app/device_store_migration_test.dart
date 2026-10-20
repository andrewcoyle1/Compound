import 'dart:io';

import 'package:compound/app/device_store_migration.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:device_store/device_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_session/training_session.dart';

void main() {
  group('migrateDeviceFiles', () {
    late Directory support;

    setUp(() => support = Directory.systemTemp.createTempSync('support'));
    tearDown(() => support.deleteSync(recursive: true));

    File file(String name) => File('${support.path}/$name');

    test('moves both files into the store and deletes them', () {
      file(
        'dismissed_target_proposals.json',
      ).writeAsStringSync('{"dismissedTargetProposalKcal.a":2300.0,"bad":"x"}');
      file('exercise_unit_preferences.json').writeAsStringSync(
        '{"exercise_unit_preference_a_bench":{"exerciseModelId":"bench",'
        '"weightUnit":"pounds","distanceUnit":"miles",'
        '"weightUnitIsChosen":true},"bad":3}',
      );
      final store = InMemoryDeviceStore();

      migrateDeviceFiles(store, support);

      expect(ProposalDismissals(store: store).of('a'), 2300);
      final units = UnitPreferenceStore(store: store).of('a', 'bench');
      expect(units.weightUnitIsChosen, isTrue);
      expect(units.distanceUnit, DistanceUnit.miles);
      expect(store.keys, {
        'dismissedTargetProposalKcal.a',
        'exercise_unit_preference_a_bench',
      });
      expect(file('dismissed_target_proposals.json').existsSync(), isFalse);
      expect(file('exercise_unit_preferences.json').existsSync(), isFalse);
    });

    test('keeps what the store already holds', () {
      file('dismissed_target_proposals.json')
          .writeAsStringSync('{"dismissedTargetProposalKcal.a":2300.0}');
      final store = InMemoryDeviceStore({
        'dismissedTargetProposalKcal.a': 1900.0,
      });

      migrateDeviceFiles(store, support);

      expect(store.getDouble('dismissedTargetProposalKcal.a'), 1900);
    });

    test('deletes a file it cannot read, and does nothing without files', () {
      file('exercise_unit_preferences.json').writeAsStringSync('{');
      file('dismissed_target_proposals.json').writeAsStringSync('[1]');
      final store = InMemoryDeviceStore();

      migrateDeviceFiles(store, support);
      migrateDeviceFiles(store, support);

      expect(store.keys, isEmpty);
      expect(support.listSync(), isEmpty);
    });
  });
}
