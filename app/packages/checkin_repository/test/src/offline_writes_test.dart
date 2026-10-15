import 'package:checkin_repository/checkin_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contract.dart';
import '../helpers/offline_firestore.dart';

// Offline, cloud_firestore's write futures never complete, as the server
// never acknowledges. The repository's writes must complete anyway, and a
// refusal once the server answers must reach onWriteError
// (docs/specs/flutter/firestore-contract.md, Policy).
void main() {
  group('FirestoreCheckInRepository offline', () {
    late OfflineFirestore firestore;
    late List<(String, String)> refused;
    late FirestoreCheckInRepository subject;

    // FieldValue.delete() binds to whichever FieldValue factory is installed when it is

    // first called. fake_cloud_firestore installs its own only when a fake is built, so

    // build one first: otherwise, when this file runs before the Firestore tests in the

    // same isolate (very_good test's optimisation), they get the method-channel factory.

    setUpAll(FakeFirebaseFirestore.new);

    setUp(() {
      firestore = OfflineFirestore();
      refused = [];
      subject = FirestoreCheckInRepository(
        firestore: firestore,
        onWriteError: (path, error, _) =>
            refused.add((path, (error as FirebaseException).code)),
      );
    });

    test(
      'the check-in writes complete offline; a refusal is reported',
      () async {
        final settings = NutritionStrategySettings.fromFirestore(
          modelFixture('nutrition_strategy_settings', 'full'),
        );
        final annotation = NutritionDayAnnotation.fromFirestore(
          modelFixture('nutrition_day_annotation', 'full'),
        );
        final strategy =
            'users/${settings.authorId}/nutrition_strategy_settings/'
            'nutrition_strategy_settings';
        const record = 'users/u/check_in_record/${CheckInRecord.documentId}';
        const loggingBreak = 'users/u/logging_break/${LoggingBreak.documentId}';
        firestore.cached[loggingBreak] = storedFixture(
          'logging_break',
          'minimal',
        );
        final day = DateTime.utc(2026, 10, 12);
        await subject.saveStrategySettings(settings);
        await subject.saveDayAnnotations('u', [annotation]);
        await subject.startLoggingBreak('u', day);
        await subject.endLoggingBreak('u', day);
        await subject.markCheckInCompleted('u', day);
        await subject.markCheckInSkipped('u', day);
        expect(firestore.writes, [
          strategy,
          'batch',
          loggingBreak,
          loggingBreak,
          record,
          record,
        ]);
        expect(refused, isEmpty);

        firestore.refuse('permission-denied');
        await pumpEventQueue();

        expect(refused, [
          for (final path in [
            strategy,
            'users/u/nutrition_day_annotations',
            loggingBreak,
            loggingBreak,
            record,
            record,
          ])
            (path, 'permission-denied'),
        ]);
      },
    );
  });
}
