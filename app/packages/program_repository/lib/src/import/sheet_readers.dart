import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:program_repository/src/import/program_sheet.dart';
import 'package:xml/xml.dart';

/// [bytes] as CSV ([readCsv]): UTF-8, else Latin-1, as Swift's
/// `CSVReader` decodes them.
SheetGrid readCsvBytes(List<int> bytes) {
  String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    text = latin1.decode(bytes);
  }
  return readCsv(text);
}

/// RFC 4180 CSV as a grid of text cells (Swift `CSVReader`): quoted fields,
/// doubled quotes inside them, line breaks inside quotes, and CRLF, LF or
/// CR line endings. A leading byte order mark is dropped, and an empty
/// field is a null cell.
SheetGrid readCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var afterQuote = false;

  void endField() {
    row.add(field.toString());
    field.clear();
    afterQuote = false;
  }

  void endRow() {
    endField();
    rows.add(row);
    row = [];
  }

  var start = 0;
  while (start < text.length && text[start] == '\u{FEFF}') {
    start++;
  }
  for (var i = start; i < text.length; i++) {
    final character = text[i];
    // Swift reads "\r\n" as one character.
    final crlf =
        character == '\r' && i + 1 < text.length && text[i + 1] == '\n';
    if (inQuotes) {
      if (character == '"') {
        inQuotes = false;
        afterQuote = true;
      } else {
        field.write(character);
      }
      continue;
    }
    switch (character) {
      case '"':
        // A quote straight after a closing quote is an escaped quote.
        if (afterQuote) field.write('"');
        inQuotes = true;
      case ',':
        endField();
      case '\n' || '\r':
        if (crlf) i++;
        endRow();
      default:
        field.write(character);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty || afterQuote) endRow();

  return [
    for (final fields in rows)
      [
        for (final text in fields)
          if (text.isEmpty) null else SheetCell(text),
      ],
  ];
}

/// The first sheet of an `.xlsx` as a grid of cells (Swift `XLSXReader`):
/// shared and inline strings, numbers, dates (a number whose style is a
/// date format), hyperlinks, and merged ranges, whose top-left value fills
/// every cell of the range. Throws [UnreadableFileError] when [bytes] are
/// not a workbook.
SheetGrid readXlsx(List<int> bytes) {
  try {
    return _XlsxReader(ZipDecoder().decodeBytes(bytes)).grid();
  } on ProgramImportError {
    rethrow;
  } on Object {
    throw const UnreadableFileError();
  }
}

class _XlsxReader {
  new(this.archive);

  final Archive archive;

  XmlElement? entry(String path) => switch (archive.findFile(path)) {
    final file? => XmlDocument.parse(utf8.decode(file.content)).rootElement,
    null => null,
  };

  SheetGrid grid() {
    final sheetPath = firstSheetPath();
    final sheet = entry(sheetPath);
    if (sheet == null) throw const UnreadableFileError();
    final shared = switch (entry('xl/sharedStrings.xml')) {
      final root? => [for (final si in _children(root, 'si')) _inlineText(si)],
      null => const <String>[],
    };
    final dateStyles = switch (entry('xl/styles.xml')) {
      final styles? => _dateStyleIndexes(styles),
      null => const <int>{},
    };
    final links = hyperlinks(sheet, sheetPath);

    final cells = <(int, int), SheetCell>{};
    for (final cell in _descendants(sheet, 'c')) {
      final ref = _reference(_attribute(cell, 'r'));
      if (ref == null) continue;
      final value = _value(cell, shared, dateStyles);
      if (value != null) cells[ref] = value.linked(links[ref]);
    }

    for (final merge in _descendants(sheet, 'mergeCell')) {
      final corners = [
        for (final part in (_attribute(merge, 'ref') ?? '').split(':'))
          ?_reference(part),
      ];
      if (corners.length != 2) continue;
      final topLeft = cells[corners[0]];
      if (topLeft == null) continue;
      for (var row = corners[0].$1; row <= corners[1].$1; row++) {
        for (var column = corners[0].$2; column <= corners[1].$2; column++) {
          cells[(row, column)] = topLeft;
        }
      }
    }

    final rowCount =
        cells.keys.fold(-1, (max, ref) => ref.$1 > max ? ref.$1 : max) + 1;
    final columnCount =
        cells.keys.fold(-1, (max, ref) => ref.$2 > max ? ref.$2 : max) + 1;
    final grid = [
      for (var row = 0; row < rowCount; row++)
        List<SheetCell?>.filled(columnCount, null),
    ];
    cells.forEach((ref, cell) => grid[ref.$1][ref.$2] = cell);
    return grid;
  }

  /// The workbook's first sheet, through its relationship id.
  String firstSheetPath() {
    final id = switch (entry('xl/workbook.xml')) {
      final workbook? => _descendants(
        workbook,
        'sheet',
      ).map((sheet) => _attribute(sheet, 'id')).firstOrNull,
      null => null,
    };
    final target = switch (entry('xl/_rels/workbook.xml.rels')) {
      final rels? when id != null =>
        _descendants(rels, 'Relationship')
            .where((node) => _attribute(node, 'Id') == id)
            .map((node) => _attribute(node, 'Target'))
            .firstOrNull,
      _ => null,
    };
    if (target == null) throw const UnreadableFileError();
    return target.startsWith('/') ? target.substring(1) : 'xl/$target';
  }

  /// The sheet's hyperlinks by cell. External links are in the sheet's
  /// relationships; links within the workbook carry a `location` instead
  /// and are skipped.
  Map<(int, int), String> hyperlinks(XmlElement sheet, String sheetPath) {
    final elements = _descendants(sheet, 'hyperlink').toList();
    if (elements.isEmpty) return const {};
    final parts = sheetPath.split('/');
    final folder = parts.sublist(0, parts.length - 1).join('/');
    final targets = <String, String>{};
    if (entry('$folder/_rels/${parts.last}.rels') case final rels?) {
      for (final node in _descendants(rels, 'Relationship')) {
        final id = _attribute(node, 'Id');
        final target = _attribute(node, 'Target');
        if (id != null && target != null) targets.putIfAbsent(id, () => target);
      }
    }
    return {
      for (final element in elements)
        ?_reference(_attribute(element, 'ref')?.split(':').first):
            ?targets[_attribute(element, 'id')],
    };
  }
}

Iterable<XmlElement> _descendants(XmlElement node, String name) =>
    node.descendantElements.where((element) => element.name.local == name);

Iterable<XmlElement> _children(XmlElement node, String name) =>
    node.childElements.where((element) => element.name.local == name);

String? _attribute(XmlElement node, String name) => node.attributes
    .where((attribute) => attribute.name.local == name)
    .firstOrNull
    ?.value;

/// The text directly inside [node].
String _text(XmlElement node) => node.children
    .where((child) => child is XmlText || child is XmlCDATA)
    .map((child) => child.value)
    .join();

/// An `<si>` or `<is>`'s text, joined across rich-text runs, without
/// phonetic (`rPh`) runs.
String _inlineText(XmlElement node) => [
  for (final child in node.childElements)
    switch (child.name.local) {
      't' => _text(child),
      'r' => _children(child, 't').map(_text).join(),
      _ => '',
    },
].join();

/// The `cellXfs` indexes whose number format is a date: built-in ids
/// 14–22, or a custom format with d, m or y outside quotes and brackets.
Set<int> _dateStyleIndexes(XmlElement styles) {
  final dateFormats = {for (var id = 14; id <= 22; id++) id};
  for (final format in _descendants(styles, 'numFmt')) {
    final id = int.tryParse(_attribute(format, 'numFmtId') ?? '');
    final code = _attribute(format, 'formatCode');
    if (id == null || code == null) continue;
    final bare = code
        .replaceAll(RegExp(r'"[^"]*"|\[[^\]]*\]'), '')
        .toLowerCase();
    if (RegExp('[dmy]').hasMatch(bare)) dateFormats.add(id);
  }
  final xfs = [
    for (final cellXfs in _children(styles, 'cellXfs').take(1))
      ..._children(cellXfs, 'xf'),
  ];
  return {
    for (var index = 0; index < xfs.length; index++)
      if (dateFormats.contains(
        int.tryParse(_attribute(xfs[index], 'numFmtId') ?? ''),
      ))
        index,
  };
}

SheetCell? _value(XmlElement cell, List<String> shared, Set<int> dateStyles) {
  final raw = _children(cell, 'v').map(_text).firstOrNull;
  switch (_attribute(cell, 't')) {
    case 's':
      final index = int.tryParse(raw ?? '');
      if (index == null || index < 0 || index >= shared.length) return null;
      return SheetCell(shared[index]);
    case 'inlineStr':
      return _children(
        cell,
        'is',
      ).map((node) => SheetCell(_inlineText(node))).firstOrNull;
    case 'str' || 'e':
      return raw == null ? null : SheetCell(raw);
    case 'b':
      return raw == null ? null : SheetCell(raw == '1' ? 'TRUE' : 'FALSE');
    case 'd':
      return raw == null ? null : SheetCell(raw, date: DateTime.tryParse(raw));
    default:
      if (raw == null) return null;
      final number = double.tryParse(raw);
      if (number == null) return SheetCell(raw);
      final style = int.tryParse(_attribute(cell, 's') ?? '');
      if (style != null && dateStyles.contains(style)) {
        final date = DateTime.fromMicrosecondsSinceEpoch(
          ((number - 25569) * 86400e6).round(),
          isUtc: true,
        );
        return SheetCell(
          date.toIso8601String().substring(0, 10),
          date: date,
          number: number,
        );
      }
      final integral = number == number.roundToDouble() && number.abs() < 1e15;
      return SheetCell(
        integral ? number.toInt().toString() : number.toString(),
        number: number,
      );
  }
}

/// "B12" as a 0-based row and column.
(int, int)? _reference(String? text) {
  final match = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(text ?? '');
  if (match == null) return null;
  final row = int.parse(match[2]!);
  if (row < 1) return null;
  var column = 0;
  for (final unit in match[1]!.toUpperCase().codeUnits) {
    column = column * 26 + unit - 64;
  }
  return (row - 1, column - 1);
}
