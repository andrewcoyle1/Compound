// The workbook parts below are XML split across adjacent strings, which
// carry no whitespace on purpose.
// ignore_for_file: missing_whitespace_between_adjacent_strings

// Swift CSVReaderTests and XLSXReaderTests. sample-program.xlsx is
// openpyxl's output (inline strings, deflated entries, real date cells, a
// hyperlink, merged day cells); shared-stored.xlsx is hand-written with
// shared strings and stored entries.
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';

import '../../helpers/program_fixtures.dart';

List<List<String?>> _texts(String csv) => [
  for (final row in readCsv(csv)) [for (final cell in row) cell?.text],
];

SheetCell? _cell(SheetGrid grid, String ref) {
  final column = ref.codeUnitAt(0) - 65;
  final row = int.parse(ref.substring(1)) - 1;
  if (row >= grid.length || column >= grid[row].length) return null;
  return grid[row][column];
}

/// A workbook of [parts].
List<int> _xlsx(Map<String, String> parts) {
  final archive = Archive();
  parts.forEach(
    (name, text) => archive.add(ArchiveFile.bytes(name, utf8.encode(text))),
  );
  return ZipEncoder().encodeBytes(archive);
}

const _workbook = {
  'xl/workbook.xml': '<workbook xmlns:r="r"><sheets><sheet name="S" sheetId="1" r:id="rId1"/></sheets></workbook>',
  'xl/_rels/workbook.xml.rels': '<Relationships><Relationship Id="rId1" Target="/xl/worksheets/s.xml"/></Relationships>',
};

void main() {
  group('readCsv', () {
    test('plain fields split on commas and empty fields are null', () {
      expect(_texts('a,b,,d\n'), [
        ['a', 'b', null, 'd'],
      ]);
    });

    test('a quoted field keeps its commas and doubled quotes', () {
      expect(_texts('"Press, incline","He said ""go""",x'), [
        ['Press, incline', 'He said "go"', 'x'],
      ]);
    });

    test('a line break inside quotes stays in the field', () {
      expect(_texts('"Pause,\r\nthen drive",2\r\nnext,3'), [
        ['Pause,\r\nthen drive', '2'],
        ['next', '3'],
      ]);
    });

    test('CRLF, LF and CR all end a row, and a byte order mark is dropped', () {
      expect(_texts('\u{FEFF}a\r\nb\nc\rd'), [
        ['a'],
        ['b'],
        ['c'],
        ['d'],
      ]);
    });

    test('the sample program reads row for row', () {
      final grid = readCsvBytes(fixtureBytes('sample-program.csv'));
      expect(grid, hasLength(49));
      expect(grid[5][1]?.text, 'S1: Incline Press');
      expect(grid[5][5]?.text, '2025-06-08');
    });

    test('bytes that are not UTF-8 read as Latin-1', () {
      expect(readCsvBytes([0x63, 0x61, 0x66, 0xE9])[0][0]?.text, 'café');
    });
  });

  group('readXlsx', () {
    SheetGrid sample() => readXlsx(fixtureBytes('sample-program.xlsx'));

    test('inline strings from a deflated sheet read as text', () {
      final grid = sample();
      expect(_cell(grid, 'A1')?.text, 'Sample Program');
      expect(_cell(grid, 'B4')?.text, 'Exercise');
      expect(_cell(grid, 'B6')?.text, 'S1: Incline Press');
    });

    test('shared strings from a stored sheet join rich runs and skip '
        'phonetic runs', () {
      final grid = readXlsx(fixtureBytes('shared-stored.xlsx'));
      expect(_cell(grid, 'A1')?.text, 'Exercise');
      expect(_cell(grid, 'C1')?.text, 'Working Sets');
      expect(_cell(grid, 'A2')?.text, 'Leg Curl & Raise ');
      expect(_cell(grid, 'C2')?.number, 3);
      expect(_cell(grid, 'D2')?.text, 'inline');
      expect(_cell(grid, 'B1'), isNull);
    });

    test('a number cell carries its value and integral text', () {
      final grid = sample();
      expect(_cell(grid, 'E6')?.number, 2);
      expect(_cell(grid, 'E6')?.text, '2');
      expect(_cell(grid, 'E6')?.date, isNull);
    });

    test(
      'a number in a date format reads as the date from the 1900 serial',
      () {
        final grid = sample();
        final reps = _cell(grid, 'F6')!;
        expect(reps.text, '2025-06-08');
        expect(_cell(grid, 'D6')?.text, '2025-02-03');
        expect(reps.date, DateTime.utc(2025, 6, 8));
      },
    );

    test("a hyperlink lands on its cell through the sheet's relationships", () {
      final grid = sample();
      expect(
        _cell(grid, 'B6')?.hyperlink,
        'https://example.com/videos/incline-press',
      );
      expect(_cell(grid, 'B7')?.hyperlink, isNull);
    });

    test('a merged range fills every cell with its top-left value', () {
      final grid = sample();
      for (var row = 6; row <= 10; row++) {
        expect(_cell(grid, 'A$row')?.text, 'Upper');
      }
      expect(_cell(grid, 'A11')?.text, 'Lower');
    });

    test('a file that is not a zip is unreadable', () {
      expect(
        () => readXlsx(utf8.encode('Exercise,Sets')),
        throwsA(const UnreadableFileError()),
      );
    });

    test('a zip with no workbook, or no sheet behind it, is unreadable', () {
      expect(
        () => readXlsx(_xlsx({'other.xml': '<a/>'})),
        throwsA(const UnreadableFileError()),
      );
      expect(
        () => readXlsx(_xlsx(_workbook)),
        throwsA(const UnreadableFileError()),
      );
    });

    test('every cell type, custom date formats, merges and links', () {
      final grid = readXlsx(
        _xlsx({
          ..._workbook,
          'xl/styles.xml':
              '<styleSheet><numFmts><numFmt numFmtId="164" formatCode="&quot;day&quot; [Red]0"/>'
              '<numFmt numFmtId="165" formatCode="yyyy-mm"/><numFmt formatCode="d"/></numFmts>'
              '<cellXfs><xf numFmtId="0"/><xf numFmtId="164"/><xf numFmtId="165"/><xf/></cellXfs></styleSheet>',
          'xl/worksheets/_rels/s.xml.rels': '<Relationships><Relationship Id="rId9" Target="https://x"/><Relationship Id="rId8"/></Relationships>',
          'xl/worksheets/s.xml':
              '<worksheet xmlns:r="r"><sheetData><row>'
              '<c r="A1" t="s"><v>7</v></c>'
              '<c r="B1" t="str"><v>formula</v></c>'
              '<c r="C1" t="e"><v>#DIV/0!</v></c>'
              '<c r="D1" t="b"><v>1</v></c>'
              '<c r="E1" t="b"><v>0</v></c>'
              '<c r="F1" t="d"><v>2025-06-08T00:00:00Z</v></c>'
              '<c r="G1" s="1"><v>2.5</v></c>'
              '<c r="H1" s="2"><v>45816</v></c>'
              '<c r="I1"><v>abc</v></c>'
              '<c r="J1"/><c t="str"><v>no ref</v></c>'
              '<c r="K1" t="str"/><c r="L1" t="b"/><c r="M1" t="d"/><c r="N1" t="s"/>'
              '<c r="O1" t="inlineStr"><is><r><t>a</t></r><r><t>b</t></r><rPh><t>x</t></rPh></is></c>'
              '</row><row><c r="A2" t="str"><v>merged</v></c></row></sheetData>'
              '<mergeCells><mergeCell ref="A2:B3"/><mergeCell ref="C5:D6"/><mergeCell ref="A9"/></mergeCells>'
              '<hyperlinks><hyperlink ref="B1" r:id="rId9"/><hyperlink ref="C1" location="S!A1"/>'
              '<hyperlink ref="zz" r:id="rId9"/></hyperlinks></worksheet>',
        }),
      );
      expect(grid, hasLength(3));
      expect(_cell(grid, 'A1'), isNull);
      expect(_cell(grid, 'B1')?.text, 'formula');
      expect(_cell(grid, 'B1')?.hyperlink, 'https://x');
      expect(_cell(grid, 'C1')?.text, '#DIV/0!');
      expect(_cell(grid, 'C1')?.hyperlink, isNull);
      expect(_cell(grid, 'D1')?.text, 'TRUE');
      expect(_cell(grid, 'E1')?.text, 'FALSE');
      expect(_cell(grid, 'F1')?.date, DateTime.utc(2025, 6, 8));
      expect(_cell(grid, 'G1')?.text, '2.5');
      expect(_cell(grid, 'H1')?.text, '2025-06-08');
      expect(_cell(grid, 'I1')?.text, 'abc');
      expect(_cell(grid, 'J1'), isNull);
      expect(_cell(grid, 'K1'), isNull);
      expect(_cell(grid, 'O1')?.text, 'ab');
      for (final ref in ['A2', 'B2', 'A3', 'B3']) {
        expect(_cell(grid, ref)?.text, 'merged');
      }
    });
  });
}
