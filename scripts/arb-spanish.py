#!/usr/bin/env python3
"""Fill app_es.arb from the Swift app's Spanish, and check it is complete.

The Swift catalog (Compound/Localizable.xcstrings) is 100% Spanish. When a Flutter message's
English text matches a catalog key, its Spanish carries over, placeholders included: `%@`,
`%lld` and `%1$@` map to the ARB message's `{name}` placeholders in order.

    python3 scripts/arb-spanish.py            # add the Spanish for every new English message
    python3 scripts/arb-spanish.py --check    # fail if any English message has no Spanish (CI)
    python3 scripts/arb-spanish.py --self-test

ICU plural/select messages are never filled automatically; translate those by hand.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARB_DIR = ROOT / "app/lib/l10n/arb"
CATALOG = ROOT / "Compound/Localizable.xcstrings"

SWIFT_ARG = re.compile(r"%(?:(\d+)\$)?(?:lld|ld|d|@|lf|f|\.\d+f)")
ARB_ARG = re.compile(r"\{(\w+)\}")
ICU = re.compile(r"\{\w+,\s*(plural|select)")


def messages(arb):
    return {k: v for k, v in arb.items() if not k.startswith("@")}


def shape(text, pattern):
    """The text with every placeholder replaced by one marker, so English forms can be compared."""
    return pattern.sub("\x00", text.replace("%%", "%"))


def spanish_index(catalog):
    """English shape -> Spanish string, for every translated plain (non-plural) catalog entry."""
    index = {}
    for key, entry in catalog["strings"].items():
        unit = entry.get("localizations", {}).get("es", {}).get("stringUnit")
        if unit and unit.get("value"):
            index.setdefault(shape(key, SWIFT_ARG), unit["value"])
    return index


def to_arb(spanish, names):
    """Spanish catalog value -> ARB text, with Swift placeholders renamed to the ARB names."""
    counter = iter(range(len(names)))

    def name(match):
        position = int(match.group(1)) - 1 if match.group(1) else next(counter)
        return "{" + names[position] + "}"

    return SWIFT_ARG.sub(name, spanish).replace("%%", "%")


def fill(english, spanish, index):
    """The Spanish messages after filling; and the English keys still missing one."""
    result = dict(spanish)
    missing = []
    for key, text in messages(english).items():
        if key in messages(spanish):
            continue
        found = None if ICU.search(text) else index.get(shape(text, ARB_ARG))
        if found is None:
            missing.append(key)
        else:
            result[key] = to_arb(found, ARB_ARG.findall(text))
    return result, missing


def ordered(english, spanish):
    """Spanish in the English file's key order, then anything Spanish-only."""
    out = {"@@locale": "es"}
    for key in english:
        if not key.startswith("@") and key in spanish:
            out[key] = spanish[key]
    out.update({k: v for k, v in spanish.items() if k not in out})
    return out


def main(argv):
    if "--self-test" in argv:
        return self_test()
    english = json.loads((ARB_DIR / "app_en.arb").read_text(encoding="utf-8"))
    es_path = ARB_DIR / "app_es.arb"
    spanish = json.loads(es_path.read_text(encoding="utf-8"))
    if "--check" in argv:
        missing = [k for k in messages(english) if k not in messages(spanish)]
        for key in missing:
            print(f"app_es.arb is missing {key!r}: {english[key]!r}")
        return 1 if missing else 0
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    result, missing = fill(english, spanish, spanish_index(catalog))
    es_path.write_text(json.dumps(ordered(english, result), ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
    for key in missing:
        print(f"translate by hand: {key!r}: {english[key]!r}")
    return 0


def self_test():
    catalog = {"strings": {
        "Sign Out": {"localizations": {"es": {"stringUnit": {"value": "Cerrar sesión"}}}},
        "%1$@ of %2$@": {"localizations": {"es": {"stringUnit": {"value": "%2$@ de %1$@"}}}},
        "%lld%% done": {"localizations": {"es": {"stringUnit": {"value": "%lld%% hecho"}}}},
    }}
    english = {"@@locale": "en", "signOut": "Sign Out", "setOf": "{set} of {total}",
               "done": "{percent}% done", "sets": "{n, plural, =1{1 set} other{{n} sets}}", "new": "Brand new"}
    result, missing = fill(english, {"@@locale": "es"}, spanish_index(catalog))
    assert result["signOut"] == "Cerrar sesión"
    assert result["setOf"] == "{total} de {set}", result["setOf"]
    assert result["done"] == "{percent}% hecho", result["done"]
    assert missing == ["sets", "new"], missing
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
