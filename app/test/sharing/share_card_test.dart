import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/gen/app_localizations_en.dart';
import 'package:compound/sharing/share_card/share_card_content.dart';
import 'package:compound/sharing/share_card/share_card_renderer.dart';
import 'package:compound/sharing/share_card/workout_share_card.dart';
import 'package:compound/workout_history/models/workout_session_highlights.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `ShareCardTests`: what the card says, and that it renders at
/// the size the platforms expect.
void main() {
  final l10n = AppLocalizationsEn();
  final start = DateTime(2026, 6, 3, 9);

  WorkoutSetModel set(
    int reps,
    double? weightKg, {
    bool isWarmup = false,
    String? side,
  }) => WorkoutSetModel(
    id: 'set-$reps-$weightKg-$side-$isWarmup',
    authorId: 'me',
    index: 1,
    reps: reps,
    weightKg: weightKg,
    sideRawValue: side,
    isWarmup: isWarmup,
    completedAt: start,
    dateCreated: start,
  );

  WorkoutSessionModel session({
    required List<WorkoutSetModel> sets,
    String id = 's1',
    String name = 'Push Day',
    int minutes = 65,
    int? streak,
    DateTime? at,
  }) {
    final date = at ?? start;
    return WorkoutSessionModel(
      id: id,
      authorId: 'me',
      name: name,
      dateCreated: date,
      dateModified: date,
      endedAt: date.add(Duration(minutes: minutes)),
      weekStreakCount: streak,
      exercises: [
        WorkoutExerciseModel(
          id: 'e-$id',
          authorId: 'me',
          templateId: 'bench',
          name: 'Bench',
          trackingMode: TrackingMode.weightReps,
          index: 1,
          sets: sets,
        ),
      ],
    );
  }

  ShareCardContent content(
    WorkoutSessionModel session, {
    UserModel? author = const UserModel(
      userId: 'me',
      submittedFirstName: 'Alex',
    ),
    List<PersonalRecord> records = const [],
    int weekly = 1,
  }) => ShareCardContent.make(
    l10n,
    session,
    author: author,
    personalRecords: records,
    weeklyWorkoutNumber: weekly,
    locale: 'en_US',
  );

  const bench = PersonalRecord(
    exerciseName: 'Bench',
    trackingMode: TrackingMode.weightReps,
    value: 100,
    reps: 5,
    weightUnit: ExerciseWeightUnit.kilograms,
  );

  test('duration reads hours and minutes', () {
    expect(
      ShareCardContent.formatDuration(l10n, const Duration(minutes: 65)),
      '1h 5m',
    );
    expect(
      ShareCardContent.formatDuration(l10n, const Duration(minutes: 45)),
      '45m',
    );
    expect(ShareCardContent.formatDuration(l10n, null), isNull);
  });

  test('volume is grouped and absent when nothing was lifted', () {
    expect(
      ShareCardContent.formatVolume(12340, locale: 'en_US'),
      '12,340\u00a0kg',
    );
    expect(ShareCardContent.formatVolume(0, locale: 'en_US'), isNull);
  });

  test('warm-ups are left out of volume and sets', () {
    final card = content(
      session(sets: [set(10, 60, isWarmup: true), set(5, 100), set(5, 100)]),
    );
    expect(card.volumeText, '1,000\u00a0kg');
    expect(card.setCount, 2);
    expect(card.durationText, '1h 5m');
    expect(card.sessionName, 'Push Day');
    expect(card.dateText, 'Wednesday, June 3');
  });

  test('a left and a right count as one set', () {
    final card = content(
      session(
        sets: [
          set(8, 20, side: 'left'),
          set(8, 20, side: 'right'),
        ],
      ),
    );
    expect(card.setCount, 1);
  });

  test('records, weekly count and streak read as on the feed', () {
    final card = content(
      session(streak: 12, sets: [set(5, 100)]),
      records: const [bench],
      weekly: 3,
    );
    expect(card.personalRecordLines, ['Bench 100\u00a0kg × 5']);
    expect(card.weeklyText, '3rd workout of the week');
    expect(card.streakText, '12-week streak');
  });

  test('a first workout with no records has no highlights', () {
    final card = content(session(sets: [set(5, 100)]));
    expect(card.personalRecordLines, isEmpty);
    expect(card.weeklyText, isNull);
    expect(card.streakText, isNull);
  });

  test("records come from the author's history", () {
    final earlier = session(
      id: 's0',
      at: DateTime(start.year, start.month, start.day - 7, 9),
      sets: [set(5, 90)],
    );
    final now = session(sets: [set(5, 100)]);
    final card = ShareCardContent.fromHistory(
      l10n,
      now,
      author: null,
      history: [earlier, now],
      firstDayOfWeek: 1,
      locale: 'en_US',
    );
    expect(card.personalRecordLines, ['Bench 100\u00a0kg × 5']);
    expect(card.firstName, isNull);
  });

  test('the card never carries a last name or display name', () {
    final card = content(
      session(sets: [set(5, 100)]),
      author: const UserModel(
        userId: 'me',
        displayName: 'alex_lifts',
        firstName: 'Alex',
        lastName: 'Smithers',
      ),
    );
    final printed = [
      card.firstName,
      card.sessionName,
      card.dateText,
      card.durationText,
      card.volumeText,
      card.weeklyText,
      card.streakText,
      ...card.personalRecordLines,
    ].nonNulls;
    expect(card.firstName, 'Alex');
    expect(
      printed.any(
        (text) => text.contains('Smithers') || text.contains('alex_lifts'),
      ),
      isFalse,
    );
  });

  for (final (format, width, height) in [
    (ShareCardFormat.story, 1080, 1920),
    (ShareCardFormat.square, 1080, 1080),
  ]) {
    testWidgets('renders ${format.name} at $width × $height pixels', (
      tester,
    ) async {
      final card = content(
        session(
          name: 'Upper Body Hypertrophy Session ' * 4,
          streak: 5,
          sets: [set(5, 100)],
        ),
        records: const [bench],
        weekly: 2,
      );
      await tester.pumpWidget(
        MaterialApp(home: Builder(builder: (_) => const SizedBox())),
      );
      final context = tester.element(find.byType(SizedBox));
      final png = await tester.runAsync(
        () => renderShareCard(
          context,
          WorkoutShareCard(
            content: card,
            format: format,
            accent: Colors.indigo,
            l10n: l10n,
          ),
          size: format.size,
        ),
      );
      final image = (await tester.runAsync(() => _decode(png!)))!;
      expect((image.width, image.height), (width, height));
      // The app icon's volt background (#C8F31D), top left, over the dark
      // gradient: the icon loaded before the card was drawn.
      final inset = ((format == ShareCardFormat.story ? 28 : 20) + 4) * 3;
      final pixels = (await tester.runAsync(image.toByteData))!;
      final at = (inset * width + inset) * 4;
      expect(
        [for (var i = 0; i < 3; i++) pixels.getUint8(at + i)],
        [closeTo(0xC8, 8), closeTo(0xF3, 8), closeTo(0x1D, 8)],
      );
    });
  }
}

Future<ui.Image> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  return (await codec.getNextFrame()).image;
}
