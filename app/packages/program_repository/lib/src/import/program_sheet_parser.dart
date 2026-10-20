import 'package:program_repository/src/import/program_sheet.dart';

enum _Kind {
  technique,
  warmupSets,
  workingSets,
  reps,
  earlyRpe,
  lastRpe,
  rest,
  notes,
}

/// The column rules, in the order a name meets them.
final _rules = <_Kind, bool Function(String)>{
  _Kind.technique: (n) => n.contains('intensity') || n.contains('technique'),
  _Kind.warmupSets: (n) => n.startsWith('warm'),
  _Kind.workingSets: (n) => n.startsWith('working sets') || n == 'sets',
  _Kind.reps: (n) => n.startsWith('reps') || n.startsWith('rep range'),
  _Kind.earlyRpe: (n) => n.startsWith('early') && n.contains('rpe'),
  _Kind.lastRpe: (n) => n.startsWith('last') && n.contains('rpe'),
  _Kind.rest: (n) => n.startsWith('rest'),
  _Kind.notes: (n) => n.startsWith('notes'),
};

/// Where each value is on a header's rows, by column index (Swift
/// `ProgramSheetParser.Columns`).
class SheetColumns {
  new _(this.exercise, this.marker);

  /// The columns [header] names, or null when it has no "Exercise" column.
  /// The first rule a name meets places it; a later column of the same
  /// kind is ignored, as are unknown columns ("Set 1"…).
  static SheetColumns? from(List<SheetCell?> header) {
    final names = [for (final cell in header) _name(cell)];
    final exercise = names.indexOf('exercise');
    if (exercise < 0) return null;
    final first = names.indexWhere((name) => name.isNotEmpty);
    final columns = SheetColumns._(exercise, first < exercise ? first : null);
    final rir = <(int, int)>[];
    for (var column = 0; column < names.length; column++) {
      final name = names[column];
      if (column == exercise || name.isEmpty) continue;
      if (name.startsWith('rir')) {
        rir.add((_setNumber(name) ?? rir.length + 1, column));
      } else if (name.startsWith('substitution')) {
        columns.substitutions.add(column);
      } else if (_rules.entries
              .where((rule) => rule.value(name))
              .firstOrNull
              ?.key
          case final kind?) {
        columns._at.putIfAbsent(kind, () => column);
      }
    }
    columns.rir = _bySet(rir);
    return columns;
  }

  /// The exercise column.
  final int exercise;

  /// Where the week label sits on the header row, and so where day names
  /// sit on exercise rows: the first named column before Exercise. Null
  /// when Exercise comes first.
  final int? marker;

  final Map<_Kind, int> _at = {};

  /// The intensity technique column.
  int? get technique => _at[_Kind.technique];

  /// The warm-up sets column.
  int? get warmupSets => _at[_Kind.warmupSets];

  /// The working sets column.
  int? get workingSets => _at[_Kind.workingSets];

  /// The reps column.
  int? get reps => _at[_Kind.reps];

  /// The early sets' RPE column.
  int? get earlyRpe => _at[_Kind.earlyRpe];

  /// The last set's RPE column.
  int? get lastRpe => _at[_Kind.lastRpe];

  /// The rest column.
  int? get rest => _at[_Kind.rest];

  /// The notes column.
  int? get notes => _at[_Kind.notes];

  /// The "RIR (Set n)" columns, in set order.
  List<int> rir = [];

  /// The substitution columns, left to right.
  final List<int> substitutions = [];

  /// RIR columns named on a line under the header ("Failure?" above, "RIR
  /// (Set 1)…" below), taken when the header named none.
  void absorbRirColumns(List<SheetCell?> cells) {
    if (rir.isNotEmpty) return;
    final names = [for (final cell in cells) _name(cell)];
    rir = _bySet([
      for (var column = 0; column < names.length; column++)
        if (names[column].startsWith('rir'))
          (_setNumber(names[column]) ?? column, column),
    ]);
  }

  static String _name(SheetCell? cell) =>
      _trimSpaces(cell?.text ?? '').toLowerCase();

  static int? _setNumber(String name) =>
      int.tryParse(RegExp(r'\d+').firstMatch(name)?[0] ?? '');

  static List<int> _bySet(List<(int, int)> columns) => [
    for (final column in columns..sort((a, b) => a.$1.compareTo(b.$1)))
      column.$2,
  ];
}

/// Swift's `.whitespaces`: spaces and tabs, not line breaks.
String _trimSpaces(String text) =>
    text.replaceAll(RegExp(r'^[ \t ]+|[ \t ]+$'), '');

/// [grid] as a program (Swift `ProgramSheetParser.parse`).
///
/// - A header row is any row with a cell reading "Exercise"; it sets the
///   columns until the next header row.
/// - The first column carries the structure: "Week N", "Intro Week" and
///   "Deload Week" start a week; "Rest Day" is a rest day; a name on an
///   exercise row starts a day, which carries on down the rows below. A
///   line of its own followed by a week or a header starts a block; the
///   first such line of the sheet is the program's title instead.
/// - A sheet with no block lines is one block named after the title; one
///   with no week lines is one week.
///
/// [labels] name what the sheet leaves unnamed.
ProgramSheet parseProgramSheet(
  SheetGrid grid, {
  ProgramSheetLabels labels = const ProgramSheetLabels(),
}) {
  final builder = _Builder(labels);
  SheetColumns? columns;

  for (var index = 0; index < grid.length; index++) {
    final cells = grid[index];
    final rowNumber = index + 1;
    SheetCell? cell(int? column) =>
        column != null && column < cells.length ? cells[column] : null;
    if (!cells.any((cell) => sheetText(cell) != null)) continue;

    if (SheetColumns.from(cells) case final header?) {
      columns = header;
      if (sheetText(cell(header.marker)) case final marker?
          when isWeekLabel(marker)) {
        builder.startWeek(marker);
      }
      builder.sawHeader = true;
      continue;
    }
    final exercise = columns == null ? null : sheetText(cell(columns.exercise));
    if (columns != null &&
        exercise == null &&
        cells.any(
          (cell) => sheetText(cell)?.toLowerCase().startsWith('rir') ?? false,
        )) {
      columns.absorbRirColumns(cells);
      continue;
    }
    final distinct = {for (final cell in cells) ?sheetText(cell)};
    if (distinct.length == 1) {
      _structuralLine(distinct.first, index, grid, builder);
      continue;
    }
    if (columns != null && exercise != null) {
      if (sheetText(cell(columns.marker)) case final text?) {
        final marker = sheetDayName(text);
        if (!isWeekLabel(marker) && marker != builder.dayName) {
          builder.startDay(marker, rowNumber);
        }
      }
      builder.append(_row(exercise, cell, columns, rowNumber), rowNumber);
      continue;
    }
    if (sheetText(cell(columns?.marker ?? 0)) case final marker?) {
      _structuralLine(marker, index, grid, builder);
    }
  }

  if (!builder.sawHeader) throw const NoHeaderRowError();
  final sheet = builder.finish();
  if (!sheet.blocks.any(
    (block) =>
        block.weeks.any((week) => week.days.any((day) => day.rows.isNotEmpty)),
  )) {
    throw const NoExercisesError();
  }
  return sheet;
}

/// A line with no exercise: a week, a rest day, the title, a block or a
/// day of its own.
void _structuralLine(String marker, int index, SheetGrid grid, _Builder b) {
  if (isWeekLabel(marker)) {
    b.startWeek(marker);
  } else if (marker.toLowerCase().startsWith('rest')) {
    b.addRestDay(marker, index + 1);
  } else if (b.title == null && !b.sawHeader && b.blocks.isEmpty) {
    b.title = marker;
  } else if (_startsBlock(index, grid)) {
    b.pendingBlockName = marker;
  } else if (b.weekStarted) {
    b.startDay(sheetDayName(marker), index + 1);
  }
}

/// A line of its own starts a block when the next line with anything on
/// it is a week or a header row.
bool _startsBlock(int index, SheetGrid grid) {
  for (final cells in grid.skip(index + 1)) {
    if (!cells.any((cell) => sheetText(cell) != null)) continue;
    if (SheetColumns.from(cells) != null) return true;
    final distinct = {for (final cell in cells) ?sheetText(cell)};
    return distinct.length == 1 && isWeekLabel(distinct.first);
  }
  return false;
}

ProgramSheetRow _row(
  String name,
  SheetCell? Function(int?) cell,
  SheetColumns columns,
  int number,
) {
  final workingSets = sheetRange(cell(columns.workingSets))?.high.round();
  if (workingSets == null || workingSets <= 0) {
    throw MissingWorkingSetsError(number);
  }
  final (tag, exerciseName) = supersetTag(name);
  final rest = sheetRest(cell(columns.rest));
  return ProgramSheetRow(
    exerciseName: exerciseName,
    supersetTag: tag,
    technique: sheetText(cell(columns.technique)),
    warmupSets: sheetRange(cell(columns.warmupSets)),
    workingSets: workingSets,
    reps: sheetRange(cell(columns.reps)),
    perSide: isPerSide(cell(columns.reps)),
    earlyRpe: sheetRange(cell(columns.earlyRpe)),
    lastRpe: sheetRange(cell(columns.lastRpe)),
    rirPerSet: [
      for (final column in columns.rir) sheetRange(cell(column))?.low.round(),
    ],
    rest: rest?.$1,
    restUnit: rest?.$2 ?? RestUnit.seconds,
    substitutions: [
      for (final column in columns.substitutions) ?sheetText(cell(column)),
    ],
    notes: sheetText(cell(columns.notes)),
    linkUrl: cell(columns.exercise)?.hyperlink,
    sourceRow: number,
  );
}

/// Accumulates blocks, weeks and days as the rows go by.
class _Builder {
  new(this.labels);

  final ProgramSheetLabels labels;
  String? title;
  bool sawHeader = false;
  String? pendingBlockName;
  final List<ProgramSheetBlock> blocks = [];
  ProgramSheetWeek? _week;
  ProgramSheetDay? _day;

  String? get dayName => _day?.name;

  bool get weekStarted => _week != null;

  void startWeek(String label) {
    _closeWeek();
    if (pendingBlockName case final name?) {
      blocks.add(
        ProgramSheetBlock(
          name: name,
          weeks: List<ProgramSheetWeek>.empty(growable: true),
        ),
      );
      pendingBlockName = null;
    }
    _week = ProgramSheetWeek(
      label: label,
      days: List<ProgramSheetDay>.empty(growable: true),
    );
  }

  void startDay(String name, int row, {bool isRest = false}) {
    _closeDay();
    if (_week == null) startWeek(labels.firstWeek);
    _day = ProgramSheetDay(
      name: name,
      isRest: isRest,
      rows: List<ProgramSheetRow>.empty(growable: true),
      sourceRow: row,
    );
  }

  void addRestDay(String name, int row) {
    startDay(name, row, isRest: true);
    _closeDay();
  }

  void append(ProgramSheetRow row, int number) {
    if (_day == null) startDay(labels.firstDay, number);
    _day!.rows.add(row);
  }

  ProgramSheet finish() {
    _closeWeek();
    return ProgramSheet(title: title, blocks: blocks);
  }

  void _closeDay() {
    if (_day case final day?) _week!.days.add(day);
    _day = null;
  }

  /// A week with no days ("Intro Week" on its own line, then the "Week 1"
  /// header) is not a week of its own: the header's week takes its place.
  void _closeWeek() {
    _closeDay();
    final week = _week;
    _week = null;
    if (week == null || week.days.isEmpty) return;
    if (blocks.isEmpty) {
      blocks.add(
        ProgramSheetBlock(
          name: title ?? labels.untitled,
          weeks: List<ProgramSheetWeek>.empty(growable: true),
        ),
      );
    }
    blocks.last.weeks.add(week);
  }
}

// MARK: - Values

/// The cell's text, or null when it is blank, "-", "–" or "N/A".
String? sheetText(SheetCell? cell) {
  final text = cell?.text.trim() ?? '';
  if (text.isEmpty) return null;
  return const {'-', '–', '—', 'n/a', 'na'}.contains(text.toLowerCase())
      ? null
      : text;
}

/// A day's name with its line breaks and runs of spaces collapsed: a sheet
/// wraps "Lower (Strength Focus)" inside its cell.
String sheetDayName(String text) =>
    text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).join(' ');

/// "Week 3", "Week 1 (Intro)", "Deload Week".
bool isWeekLabel(String text) {
  final lowered = text.toLowerCase();
  return RegExp(r'^week\s*\d+.*$').hasMatch(lowered) ||
      lowered.endsWith(' week');
}

/// "6-8", "6–8", "~8-9", "20", "10 per leg" and "1-2 min" as a range. A
/// date cell is the range Excel turned into it: 8 June is 6–8, month low
/// and day high. So is an ISO date written as text, which is how a date
/// cell comes out of a CSV export.
ValueRange? sheetRange(SheetCell? cell) {
  if (cell == null) return null;
  if (cell.date ?? _isoDate(cell.text) case final date?) {
    final utc = date.toUtc();
    return ValueRange(utc.month.toDouble(), utc.day.toDouble());
  }
  final text = sheetText(cell);
  if (text == null) return null;
  final match = RegExp(r'^[~≈]?\s*(\d+(?:\.\d+)?)\s*(?:-\s*(\d+(?:\.\d+)?))?')
      .firstMatch(text.replaceAll('–', '-').replaceAll('—', '-'));
  if (match == null) return null;
  final low = double.parse(match[1]!);
  return ValueRange(low, double.tryParse(match[2] ?? '') ?? low);
}

/// "10 per leg", "8 per side", "12 each arm".
bool isPerSide(SheetCell? cell) {
  final text = cell?.text.toLowerCase() ?? '';
  return const [
    'per leg',
    'per side',
    'per arm',
    'each side',
    'each leg',
    'each arm',
  ].any(text.contains);
}

/// "1-2 min" is minutes and "30-60 sec" seconds. With no unit, up to 10
/// reads as minutes.
(ValueRange, RestUnit)? sheetRest(SheetCell? cell) {
  final range = sheetRange(cell);
  if (range == null) return null;
  final text = cell!.text.toLowerCase();
  if (text.contains('min')) return (range, RestUnit.minutes);
  if (text.contains('s')) return (range, RestUnit.seconds);
  return (range, range.high <= 10 ? RestUnit.minutes : RestUnit.seconds);
}

/// "S1: Incline Press" is tag "S1" and name "Incline Press".
(String?, String) supersetTag(String name) {
  final match = RegExp(r'^([A-Za-z]{1,2}\d{1,2})\s*:\s*(.+)$').firstMatch(name);
  if (match == null) return (null, name);
  return (match[1]!.toUpperCase(), _trimSpaces(match[2]!));
}

DateTime? _isoDate(String text) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$')
      .firstMatch(_trimSpaces(text));
  if (match == null) return null;
  final [year, month, day] = [
    for (final group in [1, 2, 3]) int.parse(match[group]!),
  ];
  final date = DateTime.utc(year, month, day);
  return date.month == month && date.day == day ? date : null;
}
