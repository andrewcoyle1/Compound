// Swift ProgramSheetParserTests: the sheet rules, read from the fixtures:
// structure from the first column, columns by header name, and every way a
// value is written.
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';

import '../../helpers/program_fixtures.dart';

ProgramSheetRow _row(
  ProgramSheet sheet,
  int index, {
  int block = 0,
  int week = 0,
  int day = 0,
}) => sheet.blocks[block].weeks[week].days[day].rows[index];

ProgramSheet _parse(String csv) => parseProgramSheet(readCsv(csv));

List<SheetCell?> _header(List<String> names) => [
  for (final name in names) SheetCell(name),
];

void main() {
  group('structure', () {
    for (final (format, read) in [('xlsx', xlsxSheet), ('csv', csvSheet)]) {
      test('the title, blocks, weeks and days come from the first column '
          '($format)', () {
        final sheet = read();
        expect(sheet.title, 'Sample Program');
        expect([for (final b in sheet.blocks) b.name], ['Build', 'Peak']);
        expect(
          [
            for (final b in sheet.blocks) [for (final w in b.weeks) w.label],
          ],
          [
            ['Week 1', 'Week 2'],
            ['Week 1', 'Week 2'],
          ],
        );
        for (final block in sheet.blocks) {
          for (final week in block.weeks) {
            expect(
              [for (final d in week.days) d.name],
              ['Upper', 'Lower', 'Rest Day'],
            );
            expect([for (final d in week.days) d.isRest], [false, false, true]);
          }
        }
      });
    }

    test('a day name carries down, merged or not, until the next name', () {
      final sheet = xlsxSheet();
      // Block 1 merges the day cell over its rows; block 2 writes it on the
      // first row only.
      expect(sheet.blocks[0].weeks[0].days[0].rows, hasLength(5));
      expect(sheet.blocks[1].weeks[0].days[0].rows, hasLength(4));
      expect(
        [for (final r in sheet.blocks[0].weeks[0].days[1].rows) r.exerciseName],
        ['Squat', 'Split Squat', 'Leg Curl', 'Calf Raise'],
      );
      expect(sheet.blocks[0].weeks[0].days[0].sourceRow, 6);
    });

    test('the same exercise on two rows in a row stays two rows', () {
      final sheet = csvSheet();
      expect(_row(sheet, 2).exerciseName, 'Lateral Raise');
      expect(_row(sheet, 3).exerciseName, 'Lateral Raise');
      expect(_row(sheet, 3).workingSets, 1);
    });

    test('a sheet with no block lines is one block named after the title', () {
      final sheet = _parse(
        'My Plan\nDay,Exercise,Working Sets\nWeek 1\nPush,Press,3\n'
        'Intro Week\nPush,Press,2\nDeload Week\nPush,Press,1\n',
      );
      expect(sheet.title, 'My Plan');
      expect([for (final b in sheet.blocks) b.name], ['My Plan']);
      expect(
        [for (final w in sheet.blocks[0].weeks) w.label],
        ['Week 1', 'Intro Week', 'Deload Week'],
      );
    });

    test('a sheet with no week lines is one week', () {
      final sheet = _parse('Day,Exercise,Sets\nPush,Press,3\n,Fly,2\n');
      expect(sheet.blocks, hasLength(1));
      expect(sheet.blocks[0].weeks, hasLength(1));
      expect(sheet.blocks[0].weeks[0].label, 'Week 1');
      expect(
        [for (final r in sheet.blocks[0].weeks[0].days[0].rows) r.exerciseName],
        ['Press', 'Fly'],
      );
      expect(sheet.blocks[0].name, 'Imported Program');
    });

    test('unnamed weeks, days and blocks take the labels given', () {
      final sheet = parseProgramSheet(
        readCsv('Exercise,Sets\nPress,3\n'),
        labels: const ProgramSheetLabels(
          firstWeek: 'Semana 1',
          firstDay: 'Día 1',
          untitled: 'Programa',
        ),
      );
      expect(sheet.blocks[0].name, 'Programa');
      expect(sheet.blocks[0].weeks[0].label, 'Semana 1');
      expect(sheet.blocks[0].weeks[0].days[0].name, 'Día 1');
    });

    test('no header row is an error', () {
      expect(
        () => _parse('Week 1\nPush,Press,3\n'),
        throwsA(const NoHeaderRowError()),
      );
    });

    test('a header with no exercise rows has no exercises', () {
      expect(
        () => _parse('Day,Exercise,Sets\nWeek 1\nRest Day\n'),
        throwsA(const NoExercisesError()),
      );
    });

    // Published sheets put each structural line in a cell merged across the
    // row, put "Rest Day" in whichever column was handy, label an intro or
    // deload week on a line of its own above the "Week N" header, and name
    // the RIR columns on the line under the header beneath "Failure?".
    test('merged lines, a rest day in any column, an empty week label and '
        'RIR under the header', () {
      final sheet = _parse('''
Program,,,,,
,,Block A,,,
,,Intro Week,,,
Week 1,Exercise,Working Sets,Failure?,,
,,,RIR (Set 1),RIR (Set 2),
Push,Press,2,1,2,
Rest Day,Rest Day,Rest Day,Rest Day,Rest Day,Rest Day
,,,,Rest Day,
Week 2,Exercise,Working Sets,Failure?,,
,,,RIR (Set 1),RIR (Set 2),
Push,Press,2,0,0,
Ramping,Ramping,Ramping,Ramping,Ramping,Ramping
Week 3,Exercise,Working Sets,,,
Push,Press,3,,,

''');
      expect(sheet.title, 'Program');
      expect([for (final b in sheet.blocks) b.name], ['Block A', 'Ramping']);
      expect(
        [for (final w in sheet.blocks[0].weeks) w.label],
        ['Week 1', 'Week 2'],
      );
      expect([for (final w in sheet.blocks[1].weeks) w.label], ['Week 3']);
      expect(
        [for (final d in sheet.blocks[0].weeks[0].days) d.isRest],
        [false, true, true],
      );
      expect(_row(sheet, 0).rirPerSet, [1, 2]);
      expect(_row(sheet, 0, week: 1).rirPerSet, [0, 0]);
      expect(_row(sheet, 0, block: 1).workingSets, 3);
    });

    test('a line of its own after the weeks start is a day', () {
      final sheet = _parse(
        'Plan\nDay,Exercise,Sets\nWeek 1\nPush\n,Press,3\nPull\n,Row,3\n'
        'Notes\n',
      );
      expect(
        [for (final d in sheet.blocks[0].weeks[0].days) d.name],
        ['Push', 'Pull', 'Notes'],
      );
    });

    test('a structural word in the marker column of a row with more on it', () {
      final sheet = _parse(
        'Plan\nDay,Exercise,Sets\nWeek 1\nPush,Press,3\nWeek 2,,x\n'
        'Push,Press,3\n',
      );
      expect(
        [for (final w in sheet.blocks[0].weeks) w.label],
        ['Week 1', 'Week 2'],
      );
    });

    test('a row before any header is read by its first column', () {
      final sheet = _parse('Plan,x\nExercise,Sets\nPress,3\n');
      expect(sheet.title, 'Plan');
      expect(sheet.blocks[0].weeks[0].days[0].name, 'Day 1');
    });

    test('a block line followed by nothing starts no block', () {
      final sheet = _parse(
        'Plan\nDay,Exercise,Sets\nWeek 1\nPush,Press,3\nTrailing\n\n',
      );
      expect([for (final b in sheet.blocks) b.name], ['Plan']);
    });

    test('a row without working sets names its row', () {
      expect(
        () => _parse('Day,Exercise,Working Sets\nWeek 1\nPush,Press,N/A\n'),
        throwsA(const MissingWorkingSetsError(3)),
      );
    });
  });

  group('columns', () {
    test('unknown and set tracking columns are ignored, substitutions kept '
        'in order', () {
      final columns = SheetColumns.from(
        _header([
          'Day',
          'Exercise',
          'Set 1',
          'Substitution Option 2',
          'Rest',
          'Substitution Option 1',
          'Coach',
        ]),
      )!;
      expect(columns.exercise, 1);
      expect(columns.substitutions, [3, 5]);
      expect(columns.rest, 4);
      expect(columns.workingSets, isNull);
    });

    test('RIR columns are ordered by set number', () {
      expect(
        SheetColumns.from(_header(['Exercise', 'RIR (Set 2)', 'RIR (Set 1)']))
            ?.rir,
        [2, 1],
      );
      expect(SheetColumns.from(_header(['Exercise', 'RIR', 'RIR']))?.rir, [
        1,
        2,
      ]);
    });

    test('a later column of a kind already placed is ignored', () {
      final columns = SheetColumns.from(
        _header(['Exercise', 'Sets', 'Working Sets', 'Notes', 'Reps']),
      )!;
      expect(columns.workingSets, 1);
      expect(columns.notes, 3);
      expect(columns.reps, 4);
      expect(columns.marker, isNull);
    });

    test('RIR named under a header that names some is left alone', () {
      final columns = SheetColumns.from(_header(['Exercise', 'RIR (Set 1)']))!
        ..absorbRirColumns(_header(['', '', 'RIR (Set 1)']));
      expect(columns.rir, [1]);
    });
  });

  group('values', () {
    for (final (format, read) in [('xlsx', xlsxSheet), ('csv', csvSheet)]) {
      test('a date cell is a range of month to day ($format)', () {
        final sheet = read();
        expect(_row(sheet, 0).reps, ValueRange(6, 8));
        expect(_row(sheet, 0).warmupSets, ValueRange(2, 3));
      });
    }

    test('ranges, single values and per side reps', () {
      final sheet = csvSheet();
      expect(_row(sheet, 2).reps, ValueRange(6, 8));
      expect(_row(sheet, 3).reps, ValueRange.single(20));
      expect(_row(sheet, 2).warmupSets, ValueRange(0, 1));
      expect(_row(sheet, 4).warmupSets, isNull);
      expect(_row(sheet, 0).earlyRpe, ValueRange(7, 8));
      expect(_row(sheet, 3).earlyRpe, isNull);
      final split = _row(sheet, 1, day: 1);
      expect(split.reps, ValueRange.single(10));
      expect(split.perSide, isTrue);
      expect(_row(sheet, 0, day: 1).perSide, isFalse);
      expect(sheetRange(const SheetCell('6–8')), ValueRange(6, 8));
      expect(sheetRange(const SheetCell('8—6')), ValueRange(6, 8));
      expect(sheetRange(const SheetCell('heavy')), isNull);
      expect(sheetRange(const SheetCell('2025-13-40')), ValueRange(13, 2025));
      expect(sheetRange(null), isNull);
    });

    test('rest keeps its unit, and a dash is no rest', () {
      final sheet = csvSheet();
      expect(_row(sheet, 0).rest, isNull);
      expect(_row(sheet, 1).rest, ValueRange(1, 2));
      expect(_row(sheet, 1).restUnit, RestUnit.minutes);
      expect(_row(sheet, 2).rest, ValueRange(30, 60));
      expect(_row(sheet, 2).restUnit, RestUnit.seconds);
      expect(sheetRest(const SheetCell('3'))?.$2, RestUnit.minutes);
      expect(sheetRest(const SheetCell('90'))?.$2, RestUnit.seconds);
    });

    test('a superset prefix is stripped into its tag', () {
      final sheet = csvSheet();
      expect(_row(sheet, 0).exerciseName, 'Incline Press');
      expect(_row(sheet, 0).supersetTag, 'S1');
      expect(_row(sheet, 1).supersetTag, 'S1');
      expect(_row(sheet, 2).supersetTag, isNull);
    });

    test('techniques, substitutions, notes and N/A', () {
      final sheet = csvSheet();
      expect(_row(sheet, 0).technique, 'Failure');
      expect(_row(sheet, 3).technique, isNull);
      expect(_row(sheet, 0).substitutions, ['Machine Press', 'DB Press']);
      expect(_row(sheet, 1).substitutions, ['Cable Row']);
      expect(_row(sheet, 0).notes, 'Pause at the bottom.');
      expect(_row(sheet, 1).notes, isNull);
    });

    test('early and last RPE columns, then per-set RIR columns in the next '
        'block', () {
      final sheet = csvSheet();
      expect(_row(sheet, 1).lastRpe, ValueRange.single(9));
      expect(_row(sheet, 1).rirPerSet, isEmpty);
      expect(_row(sheet, 0, block: 1).rirPerSet, [2, 1, 0]);
      expect(_row(sheet, 2, block: 1).rirPerSet, [1, 0, null]);
      expect(_row(sheet, 1, block: 1, week: 1).rirPerSet, [2, 1, 0]);
      expect(_row(sheet, 0, block: 1).earlyRpe, isNull);
    });

    test("the exercise cell's hyperlink is the link", () {
      expect(
        _row(xlsxSheet(), 0).linkUrl,
        'https://example.com/videos/incline-press',
      );
      expect(_row(xlsxSheet(), 1).linkUrl, isNull);
    });

    test('the fixtures read the same apart from the link', () {
      final xlsx = xlsxSheet();
      final rows = xlsx.blocks[0].weeks[0].days[0].rows;
      rows[0] = rows[0].copyWith(clearLink: true);
      expect(xlsx, csvSheet());
      expect(xlsx.hashCode, csvSheet().hashCode);
      expect(xlsx, isNot(xlsxSheet()));
    });
  });
}
