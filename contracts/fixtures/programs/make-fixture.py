#!/usr/bin/env python3
"""Writes the program-import fixtures beside this script.

    python3 make-fixture.py

- sample-program.xlsx: the made-up two-block program, written with openpyxl so Excel's own
  quirks are reproduced (real date cells where a range was typed, inline strings, deflated
  entries, a hyperlink, merged day cells).
- sample-program.csv: the same grid as text, the date cells as ISO dates the way Numbers and
  Google Sheets export them.
- shared-stored.xlsx: a minimal workbook written by hand with shared strings (one of them rich
  text with a phonetic run) and stored (uncompressed) entries, the two things openpyxl never
  writes; openpyxl itself writes inline strings and deflates.

sample-program.json is not written here: it is the Swift importer's own output for this
program, encoded with `JSONEncoder`, so it is exactly the app's format.

Every exercise name and note is invented. Never put a published program's content here.
"""

import csv
import os
import zipfile
from datetime import datetime

from openpyxl import Workbook

HERE = os.path.dirname(os.path.abspath(__file__))


def d(month, day):
    """A cell Excel turned into a date: "6-8" typed into a cell becomes 8 June."""
    return datetime(2025, month, day)


BLOCK1_HEADER = ["Day", "Exercise", "Last-Set Intensity Technique", "Warm-up Sets", "Working Sets",
                 "Reps", "Early Set RPE", "Last Set RPE", "Rest", "Substitution Option 1",
                 "Substitution Option 2", "Notes", "Set 1", "Set 2"]

BLOCK2_HEADER = ["Day", "Exercise", "Intensity Technique", "Warm-up Sets", "Working Sets", "Reps",
                 "RIR (Set 1)", "RIR (Set 2)", "RIR (Set 3)", "Rest", "Substitution Option 1",
                 "Substitution Option 2", "Notes"]

LINK = "https://example.com/videos/incline-press"


def block1_upper(incline_sets):
    #       exercise, technique, warm-ups, sets, reps, early, last, rest, sub 1, sub 2, notes
    return [
        ["S1: Incline Press", "Failure", d(2, 3), incline_sets, d(6, 8), "~7-8", "9-10", "-",
         "Machine Press", "DB Press", "Pause at the bottom."],
        ["S1: Row", "Myo Reps", "1", 3, "10-12", "8", "9", "1-2 min", "Cable Row", "N/A", None],
        ["Lateral Raise", "Two Drop Sets (~25%)", "0-1", 3, "6-8", "8", "9", "30-60 sec", None, None, None],
        ["Lateral Raise", "N/A", "0", 1, "20", "-", "10", "1-2 min", None, None, "Back-off set."],
        ["Triceps Pushdown", "LLP", "-", 2, "10-12", "8", "10", "1-2 min", None, None, None],
    ]


def block1_lower():
    return [
        ["Squat", "N/A", "3-4", 3, "6-8", "7", "8", "2-4 min", "Hack Squat", "Leg Press", "Brace hard."],
        ["Split Squat", "Static Stretch (30s)", "1", 2, "10 per leg", "8", "9", "1-2 min", None, None, None],
        ["Leg Curl", "Static Hold (20 sec)", "1", 2, "8-10", "8", "9", "1-2 min", None, None, None],
        ["Calf Raise", "Lengthened Partials", "1", 3, "10-12", "8", "10", "1-2 min", None, None, None],
    ]


def block2_upper(row_rir):
    #       exercise, technique, warm-ups, sets, reps, rir 1, rir 2, rir 3, rest, sub 1, sub 2, notes
    return [
        ["Incline Press", "Failure", "2", 3, "4-6", "2", "1", "0", "2-4 min", None, None, None],
        ["Row", "Myo-reps", "1", 3, "8-10", "2", "1", row_rir, "1-2 min", None, None, None],
        ["Lateral Raise", "Three Drop Sets (~20%)", "0", 2, "10-12", "1", "0", "-", "1-2 min", None, None, None],
        ["Triceps Pushdown", "Extended Partials", "0", 2, "12-15", "1", "0", "-", "1-2 min", None, None, None],
    ]


def block2_lower():
    return [
        ["Squat", "N/A", "4", 3, "4-6", "2", "2", "1", "2-4 min", None, None, None],
        ["Split Squat", "N/A", "1", 2, "8 per side", "1", "1", "-", "1-2 min", None, None, None],
        ["Leg Curl", "Static Hold (30 sec)", "1", 2, "6-8", "1", "0", "-", "1-2 min", None, None, None],
        ["Calf Raise", "Failure", "0", 3, "15", "1", "1", "0", "30-60 sec", None, None, None],
    ]


def program_rows():
    """The whole sheet as (row, merge-ranges, hyperlinks), one list per row, columns from A."""
    rows = []

    def add(values):
        rows.append(values)
        return len(rows)

    def day(name, exercises, header_width):
        first = None
        for index, values in enumerate(exercises):
            row = [name if index == 0 else None] + values
            row += [None] * (header_width - len(row))
            number = add(row)
            first = first or number
        return first, len(rows)

    merges, links = [], []

    add(["Sample Program"])
    add([])
    add(["Build"])
    add(BLOCK1_HEADER)
    for week, incline_sets in (("Week 1", 2), ("Week 2", 3)):
        add([week])
        first, last = day("Upper", block1_upper(incline_sets), len(BLOCK1_HEADER))
        merges.append((first, last))
        if week == "Week 1":
            links.append(first)
        first, last = day("Lower", block1_lower(), len(BLOCK1_HEADER))
        merges.append((first, last))
        add(["Rest Day"])
    add([])
    add(["Peak"])
    add(BLOCK2_HEADER)
    for week, row_rir in (("Week 1", "1"), ("Week 2", "0")):
        add([week])
        day("Upper", block2_upper(row_rir), len(BLOCK2_HEADER))
        day("Lower", block2_lower(), len(BLOCK2_HEADER))
        add(["Rest Day"])
    return rows, merges, links


def write_xlsx(rows, merges, links):
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Program"
    for values in rows:
        sheet.append(values)
    for first, last in merges:
        sheet.merge_cells(f"A{first}:A{last}")
    for row in links:
        sheet.cell(row=row, column=2).hyperlink = LINK
    workbook.save(os.path.join(HERE, "sample-program.xlsx"))


def csv_text(value):
    if value is None:
        return ""
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d")
    return str(value)


def write_csv(rows):
    width = max(len(row) for row in rows)
    with open(os.path.join(HERE, "sample-program.csv"), "w", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\r\n")
        for row in rows:
            writer.writerow([csv_text(v) for v in row] + [""] * (width - len(row)))


def write_shared_stored():
    files = {
        "[Content_Types].xml": """<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/data.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>""",
        "_rels/.rels": """<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>""",
        "xl/workbook.xml": """<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="Plan" sheetId="1" r:id="rId7"/></sheets>
</workbook>""",
        "xl/_rels/workbook.xml.rels": """<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId7" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="/xl/worksheets/data.xml"/>
</Relationships>""",
        "xl/sharedStrings.xml": """<?xml version="1.0" encoding="UTF-8"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="3" uniqueCount="3">
<si><t>Exercise</t></si>
<si><r><t>Working </t></r><r><rPr><b/></rPr><t>Sets</t></r><rPh sb="0" eb="1"><t>IGNORED</t></rPh></si>
<si><t xml:space="preserve">Leg Curl &amp; Raise </t></si>
</sst>""",
        "xl/worksheets/data.xml": """<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<sheetData>
<row r="1"><c r="A1" t="s"><v>0</v></c><c r="C1" t="s"><v>1</v></c></row>
<row r="2"><c r="A2" t="s"><v>2</v></c><c r="C2"><v>3</v></c><c r="D2" t="inlineStr"><is><t>inline</t></is></c></row>
</sheetData>
</worksheet>""",
    }
    with zipfile.ZipFile(os.path.join(HERE, "shared-stored.xlsx"), "w", compression=zipfile.ZIP_STORED) as archive:
        for name, text in files.items():
            archive.writestr(name, text)


if __name__ == "__main__":
    rows, merges, links = program_rows()
    write_xlsx(rows, merges, links)
    write_csv(rows)
    write_shared_stored()
