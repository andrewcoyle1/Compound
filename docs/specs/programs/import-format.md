# Program import formats

Mesocycle library › **+** › **Import Program…** reads three formats. Nothing is saved until the
review screen's **Save Program**: exercise names the library cannot match are listed first, each
mapped to a library exercise or created as a new one. The result is one mesocycle per block, in a
macrocycle that is not started.

Code: `Compound/Managers/Training/ProgramImport/` (pure, tested in
`CompoundUnitTests/Services/Training/ProgramImport/`) and the screen in
`Compound/Core/Training/Subviews/ImportProgram/`. Fixtures, all made up:
`CompoundUnitTests/Fixtures/programs/` (`make-fixture.py` writes the `.xlsx` and `.csv`).

## Spreadsheet (`.xlsx`) and CSV (`.csv`)

The same grid either way. An `.xlsx` is read from its first sheet with no dependency (the zip's
XML, inflated with `Compression`); shared and inline strings, numbers, date cells, hyperlinks and
merged cells are understood. A CSV is RFC 4180 (quoted fields, doubled quotes, line breaks inside
quotes, CRLF or LF).

**Header row.** Any row with a cell reading `Exercise`. It sets the columns until the next header
row, so a later block can track effort differently. Columns are matched by name, ignoring case:

| Column | Header |
|---|---|
| Exercise | `Exercise` |
| Technique | contains `Intensity` or `Technique` |
| Warm-up sets | starts `Warm` |
| Working sets | starts `Working Sets`, or `Sets` |
| Reps | starts `Reps` or `Rep Range` |
| Early / last set RPE | `Early Set RPE`, `Last Set RPE` |
| RIR per set | `RIR (Set 1)`, `RIR (Set 2)`, … |
| Rest | starts `Rest` |
| Substitutions | `Substitution Option 1`, `… 2`, in order |
| Notes | starts `Notes` |

Anything else (`Set 1`… tracking columns, coach columns) is ignored.

**First column: the structure.**
- The sheet's first line of its own is the program's title (the macrocycle name).
- A later line of its own followed by a week or a header row starts a **block** (a mesocycle,
  named by the line). With no block lines the sheet is one block named after the title.
- `Week 1`, `Week 2`, `Intro Week`, `Deload Week` start a **week** (a microcycle). With no week
  lines the sheet is one week. A week label on a line of its own directly above a `Week N`
  header ("Intro Week", then the header) is the same week, not an extra one.
- A line of its own counts whichever column it sits in, and a cell merged across the row counts
  once, so `Rest Day` in the middle of a row and a block name merged over the full width both
  read as structure, never as an exercise.
- `RIR (Set 1)…` named on the line under the header (beneath a `Failure?` heading, with no
  exercise beside them) are the RIR columns for that header.
- A name on an exercise row starts a **day**, which carries on over the rows below until another
  name; a merged day cell works the same. `Rest Day` is a rest day.
- Every week of a block must have week 1's days, each with week 1's exercises by name; otherwise
  the import stops with the week and day.

**Values.**
- Ranges: `6-8`, `6–8`, `~8-9`. A cell Excel turned into a date is the range it was typed as:
  8 June is 6–8 (month, then day). An ISO date in a CSV (`2025-06-08`) reads the same.
- Reps: a range, or one value for both ends (`20`). `10 per leg` / `per side` is per side.
- Warm-ups: the upper bound (`0-1` is 1). Blank or `-` leaves the automatic warm-ups.
- Effort: early-set RPE applies to every set but the last, last-set RPE to the last;
  RIR = 10 − the upper RPE, rounded down, 0–5. `RIR (Set n)` columns are taken as given.
- Rest: the midpoint, rounded to 15 s: `1-2 min` 90 s, `30-60 sec` 45 s, `2-4 min` 180 s. `-` is
  none (the first exercise of a superset).
- `S1:`, `S2:` before a name group a superset on that day and are removed from the name.
- The same exercise on two rows in a row is two entries.
- A hyperlink on the exercise cell is the exercise's link (`.xlsx` only).
- `N/A`, `-` and blank are empty everywhere.

**Technique** sets the type of the last working set:

| Text contains | Set type |
|---|---|
| `Drop` | drop; drops from `One`…`Four` or a digit, step from `~N%` |
| `Myo` | myo-reps, 3 mini-sets |
| `LLP`, `Lengthened`, `Extend` | lengthened partials |
| `Stretch` | loaded stretch, `N s` / `N sec` long |
| `Hold` | static hold, `N s` / `N sec` long |
| `Failure` | AMRAP at RIR 0 |
| anything else | standard |

**Weeks.** Week 1 is each exercise's base targets. A later week adds a "from week N" override only
where that exercise's targets differ from the week before (a set added, an RIR changed).

**Exercise names** match the library strictly: the exact name, an alternate name, the same words
ignoring case and punctuation, then with abbreviations spelled out (`DB` Dumbbell, `BB` Barbell,
`SM` Smith Machine, `1-Arm`/`One-Arm` Single-Arm, `Pulldown` Pull-Down, `Flye` Fly). A name that
loosely matches two exercises matches neither. Substitutions are matched the same way.

### CSV example

```csv
My Program,,,,,,,,
Block A,,,,,,,,
Day,Exercise,Technique,Warm-up Sets,Working Sets,Reps,Early Set RPE,Last Set RPE,Rest
Week 1,,,,,,,,
Upper,S1: Incline Press,Failure,2-3,2,6-8,~7-8,9-10,-
,S1: Row,Myo Reps,1,3,10-12,8,9,1-2 min
,Lateral Raise,N/A,0,1,20,-,10,30-60 sec
Lower,Squat,N/A,3-4,3,6-8,7,8,2-4 min
Rest Day,,,,,,,,
Week 2,,,,,,,,
Upper,S1: Incline Press,Failure,2-3,3,6-8,~7-8,9-10,-
,S1: Row,Myo Reps,1,3,10-12,8,9,1-2 min
,Lateral Raise,N/A,0,1,20,-,10,30-60 sec
Lower,Squat,N/A,3-4,3,6-8,7,8,2-4 min
Rest Day,,,,,,,,
```

One mesocycle "Block A" of 2 weeks and three days (Upper, Lower, Rest); Incline Press goes from
2 sets to 3 in week 2.

## JSON (`.json`)

The app's own `Mesocycle` Codable form (snake-case keys, dates as seconds since 2001): either an
array of mesocycles or a single one. Each is copied under the importing user with new ids, the way
a shared mesocycle is accepted: built-in exercises and the user's own keep their id; any other
exercise is copied once as a new exercise of the user's. The macrocycle takes the mesocycle's name
when there is one, else the file's name. `CompoundUnitTests/Fixtures/programs/sample-program.json`
is the sample program in this form.
